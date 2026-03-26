# frozen_string_literal: true

require "asktive_record/llm_service"
require "asktive_record/schema_loader"
require "asktive_record/log"

module AsktiveRecord
  module Service
    # This module provides methods for handling service-based queries
    # where the LLM determines the appropriate tables and relationships based on the query.
    # It allows for more complex queries that may involve multiple tables or relationships,
    # without requiring the user to specify a target table.
    module ClassMethods
      include AsktiveRecord::SchemaLoader

      def ask(natural_language_query, options = {})
        validate_llm_api_key!
        schema_content = load_schema_content
        ensure_schema_is_not_empty!(schema_content)
        llm_service = AsktiveRecord::LlmService.new(AsktiveRecord.configuration)
        target_table = options[:table_name] || "any"
        raw_sql = llm_service.generate_sql_for_service(natural_language_query, schema_content, target_table)
        target_model = resolve_model(options[:model])
        AsktiveRecord::Query.new(natural_language_query, raw_sql, target_model)
      end

      private

      def resolve_model(provided_model)
        return provided_model if provided_model
        return ApplicationRecord if defined?(Rails) && defined?(ApplicationRecord)

        self
      end
    end
  end
end
