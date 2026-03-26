# frozen_string_literal: true

require "asktive_record/version"
require "asktive_record/error"
require "asktive_record/log"
require "asktive_record/configuration"
require "asktive_record/sql_sanitizer"
require "asktive_record/model"
require "asktive_record/service"
require "asktive_record/query"

# The AsktiveRecord module provides natural language querying capabilities
# and service/model extensions for ActiveRecord-like classes.
module AsktiveRecord
  extend Service::ClassMethods
  class << self
    attr_accessor :configuration

    # Provides access to the logger instance
    # @return [AsktiveRecord::Log]
    def logger
      AsktiveRecord::Log
    end
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end

  # Main entry point for ApplicationRecord to include AsktiveRecord behavior
  def self.included(base)
    # If the base class is a service class (inherits from AsktiveRecord directly),
    # extend it with Service module methods
    if base.superclass == Object || base.superclass.name == "Object"
      base.extend(Service::ClassMethods)
    else
      # Otherwise, it's likely an ActiveRecord model, so extend with Model module
      base.extend(Model::ClassMethods)
    end
  end

  # Class method to allow direct querying from AsktiveRecord module
  def self.ask(natural_language_query, options = {})
    # Delegate to the Service module's ask method directly
    validate_configuration!
    schema_content = load_schema_for_module
    llm_service = AsktiveRecord::LlmService.new(configuration)
    target_table = options[:table_name] || "any"
    raw_sql = llm_service.generate_sql_for_service(natural_language_query, schema_content, target_table)
    target_model = options[:model] || self
    AsktiveRecord::Query.new(natural_language_query, raw_sql, target_model)
  end

  # @api private
  def self.validate_configuration!
    return if configuration&.llm_api_key

    raise ConfigurationError, "LLM API key is not configured for AsktiveRecord."
  end

  # @api private
  def self.load_schema_for_module
    path = configuration.db_schema_path
    raise ConfigurationError, "Schema file not found at #{path}." unless File.exist?(path)

    content = File.read(path)
    raise ConfigurationError, "Schema content is empty." if content.strip.empty?

    content
  end

  private_class_method :validate_configuration!, :load_schema_for_module
end
