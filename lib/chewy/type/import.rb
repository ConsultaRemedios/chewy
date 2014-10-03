module Chewy
  class Type
    module Import
      extend ActiveSupport::Concern

      module ClassMethods
        # Perform import operation for specified documents.
        # Returns true or false depending on success.
        #
        #   UsersIndex::User.import                          # imports default data set
        #   UsersIndex::User.import User.active              # imports active users
        #   UsersIndex::User.import [1, 2, 3]                # imports users with specified ids
        #   UsersIndex::User.import users                    # imports users collection
        #   UsersIndex::User.import refresh: false           # to disable index refreshing after import
        #   UsersIndex::User.import suffix: Time.now.to_i    # imports data to index with specified suffix if such is exists
        #   UsersIndex::User.import batch_size: 300          # import batch size
        #
        # See adapters documentation for more details.
        #
        def import *args
          import_options = args.extract_options!
          bulk_options = import_options.reject { |k, v| ![:refresh, :suffix].include?(k) }.reverse_merge!(refresh: true)

          index.create!(bulk_options.slice(:suffix)) unless index.exists?
          build_root unless self.root_object

          ActiveSupport::Notifications.instrument 'import_objects.chewy', type: self do |payload|
            adapter.import(*args, import_options) do |action_objects|
              indexed_objects = self.root_object.parent_id && fetch_indexed_objects(action_objects.values.flatten, bulk_options)
              body = bulk_body(action_objects, indexed_objects)
              errors = bulk(bulk_options.merge(body: body)) if body.any?

              fill_payload_import payload, action_objects
              fill_payload_errors payload, errors if errors.present?
              !errors.present?
            end
          end
        end

        # Perform import operation for specified documents.
        # Raises Chewy::ImportFailed exception in case of import errors.
        #
        #   UsersIndex::User.import!                          # imports default data set
        #   UsersIndex::User.import! User.active              # imports active users
        #   UsersIndex::User.import! [1, 2, 3]                # imports users with specified ids
        #   UsersIndex::User.import! users                    # imports users collection
        #   UsersIndex::User.import! refresh: false           # to disable index refreshing after import
        #   UsersIndex::User.import! suffix: Time.now.to_i    # imports data to index with specified suffix if such is exists
        #   UsersIndex::User.import! batch_size: 300          # import batch size
        #
        # See adapters documentation for more details.
        #
        def import! *args
          errors = nil
          subscriber = ActiveSupport::Notifications.subscribe('import_objects.chewy') do |*args|
            errors = args.last[:errors]
          end
          import *args
          ActiveSupport::Notifications.unsubscribe(subscriber)
          raise Chewy::ImportFailed.new(self, errors) if errors.present?
          true
        end

        # Wraps elasticsearch-ruby client indices bulk method.
        # Adds `:suffix` option to bulk import to index with specified suffix.
        def bulk options = {}
          suffix = options.delete(:suffix)

          result = client.bulk options.merge(index: index.build_index_name(suffix: suffix), type: type_name)
          Chewy.wait_for_status

          extract_errors result
        end

      private

        def bulk_body(action_objects, indexed_objects = nil)
          action_objects.inject([]) do |result, (action, objects)|
            result.concat(objects.map { |object| bulk_entries(action, object, indexed_objects) }.flatten)
          end
        end

        def bulk_entries(action, object, indexed_objects = nil)
          entry = {}

          entry[:_id] = object.respond_to?(:id) ? object.id : object
          entry[:_id] = entry[:_id].to_s if entry[:_id].is_a? BSON::ObjectId
          entry[:data] = object_data(object) unless action == :delete

          if self.root_object.parent_id
            entry[:parent] = self.root_object.compose_parent(object) if object.respond_to?(:id)
          end

          indexed_object = indexed_objects && indexed_objects[entry[:_id].to_s]

          if indexed_object && self.root_object.parent_id && action == :delete
            [{ action => entry.merge(parent: indexed_object[:parent]) }]
          elsif indexed_object && self.root_object.parent_id && entry[:parent].to_s != indexed_object[:parent]
            [{ :delete => entry.except(:data).merge(parent: indexed_object[:parent]) }, { action => entry }]
          else
            [{ action => entry }]
          end
        end

        def fill_payload_import payload, action_objects
          imported = Hash[action_objects.map { |action, objects| [action, objects.count] }]
          imported.each do |action, count|
            payload[:import] ||= {}
            payload[:import][action] ||= 0
            payload[:import][action] += count
          end
        end

        def fill_payload_errors payload, errors
          errors.each do |action, errors|
            errors.each do |error, documents|
              payload[:errors] ||= {}
              payload[:errors][action] ||= {}
              payload[:errors][action][error] ||= []
              payload[:errors][action][error] |= documents
            end
          end
        end

        def object_data object
          (self.root_object ||= build_root).compose(object)[type_name.to_sym]
        end

        def extract_errors result
          result && result['items'].map do |item|
            action = item.keys.first.to_sym
            data = item.values.first
            {action: action, id: data['_id'], error: data['error']} if data['error']
          end.compact.group_by { |item| item[:action] }.map do |action, items|
            errors = items.group_by { |item| item[:error] }.map do |error, items|
              {error => items.map { |item| item[:id] }}
            end.reduce(&:merge)
            {action => errors}
          end.reduce(&:merge) || {}
        end

        def fetch_indexed_objects(objects, options = {})
          ids = objects.map { |object| object.respond_to?(:id) ? object.id : object }
          result = client.search index: index.build_index_name(suffix: options[:suffix]), type: type_name, fields: '_parent', body: { query: { ids: { values: ids } } }, search_type: 'scan', scroll: '1m'

          indexed_objects = {}

          while result = client.scroll(scroll_id: result['_scroll_id'], scroll: '1m') do
            break if result['hits']['hits'].empty?

            result['hits']['hits'].map do |hit|
              indexed_objects[hit['_id']] = { parent: hit['fields']['_parent'] }
            end
          end

          indexed_objects
        end
      end
    end
  end
end
