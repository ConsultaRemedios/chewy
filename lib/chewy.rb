require 'active_support'
require 'active_support/deprecation'
require 'active_support/core_ext'
require 'active_support/concern'
require 'active_support/json'
require 'i18n/core_ext/hash'
require 'chewy/backports/deep_dup' unless Object.respond_to?(:deep_dup)
require 'singleton'

begin
  require 'kaminari'
rescue LoadError
end
require 'elasticsearch'

require 'chewy/version'
require 'chewy/errors'
require 'chewy/config'
require 'chewy/runtime'
require 'chewy/index'
require 'chewy/type'
require 'chewy/query'
require 'chewy/fields/base'
require 'chewy/fields/root'

require 'chewy/railtie' if defined?(::Rails)

ActiveSupport.on_load(:active_record) do
  extend Chewy::Type::Observe::ActiveRecordMethods
end

ActiveSupport.on_load(:mongoid) do
  include Chewy::Type::Observe::MongoidMethods
  
  module Mongoid::Document::ClassMethods
    include Chewy::Type::Observe::ClassMethods
  end
end

# TODO
# adicionar suporte a modularização do indice CrCore::Indexes::OffersIndex
# verificar como adicionar os callbacks no mongoid
# implementar de forma definitiva todas as modificações feitas para a lib funcionar

module Chewy
  def self.derive_type name
    return name if name.is_a?(Class) && name < Chewy::Type

    index_name, type_name = name.split('#', 2)
    class_name = "CrCore::Indexes::#{index_name.camelize}Index"
    index = class_name.safe_constantize
    raise Chewy::UnderivableType.new("Can not find index named `#{class_name}`") unless index && index < Chewy::Index
    type = if type_name.present?
      index.type_hash[type_name] or raise Chewy::UnderivableType.new("Index `#{class_name}` doesn`t have type named `#{type_name}`")
    elsif index.types.one?
      index.types.first
    else
      raise Chewy::UnderivableType.new("Index `#{class_name}` has more than one type, please specify type via `#{index_name}#type_name`")
    end
  end

  def self.create_type index, target, options = {}, &block
    type = Class.new(Chewy::Type)

    adapter = if defined?(ActiveRecord) && (target.is_a?(Class) && (target < ActiveRecord::Base) || target.is_a?(::ActiveRecord::Relation))
      Chewy::Type::Adapter::ActiveRecord.new(target, options)
    elsif defined?(Mongoid) && target < Mongoid::Document
      Chewy::Type::Adapter::Mongoid.new(target, options)
    else
      Chewy::Type::Adapter::Object.new(target, options)
    end

    index.const_set(adapter.name, type)
    type.send(:define_singleton_method, :index) { index }
    type.send(:define_singleton_method, :adapter) { adapter }

    type.class_eval &block if block
    type
  end

  def self.wait_for_status
    client.cluster.health wait_for_status: Chewy.configuration[:wait_for_status] if Chewy.configuration[:wait_for_status].present?
  end

  def self.config
    Chewy::Config.instance
  end

  singleton_class.delegate *Chewy::Config.delegated, to: :config
end
