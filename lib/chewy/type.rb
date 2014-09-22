require 'chewy/index/search'
require 'chewy/type/mapping'
require 'chewy/type/wrapper'
require 'chewy/type/observe'
require 'chewy/type/actions'
require 'chewy/type/import'
require 'chewy/type/adapter/object'
require 'chewy/type/adapter/active_record'
require 'chewy/type/adapter/mongoid'

module Chewy
  class Type
    include Chewy::Index::Search
    include Mapping
    include Wrapper
    include Observe
    include Actions
    include Import

    singleton_class.delegate :client, to: :index

    def self.index
      raise NotImplementedError
    end

    def self.adapter
      raise NotImplementedError
    end

    def self.type_name
      adapter.type_name
    end

    def self.search_index
      index
    end

    def self.search_type
      type_name
    end
  end
end
