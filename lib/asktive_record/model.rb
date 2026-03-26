# frozen_string_literal: true

require "asktive_record/llm_service"
require "asktive_record/schema_loader"
require "asktive_record/log"

module AsktiveRecord
  module Model
    # Provides class-level methods for AsktiveRecord models, enabling natural language queries and configuration checks.
    module ClassMethods
      include AsktiveRecord::SchemaLoader

      def asktive_record
        return if AsktiveRecord.configuration

        raise ConfigurationError,
              "AsktiveRecord is not configured. Please run the installer and " \
              "ensure config/initializers/asktive_record.rb is set up."
      end

      def ask(natural_language_query)
        validate_llm_api_key!

        schema_content = load_schema_content
        ensure_schema_is_not_empty!(schema_content)

        llm_service = AsktiveRecord::LlmService.new(AsktiveRecord.configuration)
        current_table_name = respond_to?(:table_name) ? table_name : name.downcase.pluralize

        raw_sql = llm_service.generate_sql(natural_language_query, schema_content, current_table_name)

        AsktiveRecord::Query.new(natural_language_query, raw_sql, self)
      end
    end
  end
end
