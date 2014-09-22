require 'chewy/type/adapter/base'

module Chewy
  class Type
    module Adapter
      class Mongoid < Base
        def initialize *args
          @options = args.extract_options!
          @target = args.first
        end

        # Camelcased name, used as type class constant name.
        # For returned value 'Product' will be generated class name `ProductsIndex::Product`
        #
        def name
          @name ||= (options[:name] || target.klass).to_s.camelize.demodulize
        end

        # Splits passed objects to groups according to `:batch_size` options.
        # For every group crates hash with action keys. Example:
        #
        #   { delete: [object1, object2], index: [object3, object4, object5] }
        #
        # Returns true id all the block call returns true and false otherwise
        #
        def import *args, &block
          import_options = args.extract_options!
          batch_size = import_options.delete(:batch_size) || BATCH_SIZE
          # objects = args.flatten
          objects = @target.entries


          objects.in_groups_of(batch_size, false).map do |group|
            action_groups = group.group_by do |object|
              raise "Object is not a `#{target}`" if class_target? && !object.is_a?(target)
              delete = object.delete_from_index? if object.respond_to?(:delete_from_index?)
              delete ||= object.destroyed? if object.respond_to?(:destroyed?)
              delete ? :delete : :index
            end
            block.call action_groups
          end.all?
        end

        # Returns array of loaded objects for passed objects array. If some object
        # was not loaded, it returns `nil` in the place of this object
        #
        #   load(double(id: 1), double(id: 2), double(id: 3)) #=>
        #     # [<Product id: 1>, nil, <Product id: 3>], assuming, #2 was not found
        #
        def load *args
          load_options = args.extract_options!
          objects = args.flatten
          if class_target?
            objects.map { |object| target.wrap(object) }
          else
            objects
          end
        end

      private

        attr_reader :target, :options

        def class_target?
          @class_target ||= @target.is_a?(Class)
        end
      end
    end
  end
end