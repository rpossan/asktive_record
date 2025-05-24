require "modelm/version"
require "modelm/error"
require "modelm/configuration"
require "modelm/model"
require "modelm/service"
require "modelm/query"

module Modelm
  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end

  # Main entry point for ApplicationRecord to include Modelm behavior
  def self.included(base)
    # If the base class is a service class (inherits from Modelm directly),
    # extend it with Service module methods
    if base.superclass == Object || base.superclass.name == "Object"
      base.extend(Service::ClassMethods)
    else
      # Otherwise, it's likely an ActiveRecord model, so extend with Model module
      base.extend(Model::ClassMethods)
    end
  end
  
  # Class method to allow direct querying from Modelm module
  def self.ask(natural_language_query, options = {})
    # Delegate to the Service module's implementation
    Service::ClassMethods.instance_method(:ask).bind(self).call(natural_language_query, options)
  end
end
