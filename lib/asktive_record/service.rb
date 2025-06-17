# frozen_string_literal: true

require "asktive_record/llm_service"

module AsktiveRecord
  module Service
    # This module provides methods for handling service-based queries
    # where the LLM determines the appropriate tables and relationships based on the query.
    # It allows for more complex queries that may involve multiple tables or relationships,
    # without requiring the user to specify a target table.
    module ClassMethods
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

      def ensure_schema_is_not_empty!(schema_content)
        return unless schema_content.to_s.strip.empty?

        raise ConfigurationError,
              "Schema content is empty. Cannot proceed without database schema context."
      end

      def validate_llm_api_key!
        return if AsktiveRecord.configuration&.llm_api_key

        raise ConfigurationError, "LLM API key is not configured for AsktiveRecord."
      end

      def load_schema_content
        path = AsktiveRecord.configuration.db_schema_path
        return File.read(path) if File.exist?(path)

        attempt_schema_fallback(path)
      rescue SystemCallError => e
        raise ConfigurationError, "Error reading schema file at #{path}: #{e.message}"
      end

      def attempt_schema_fallback(path)
        puts "Schema file not found at #{path}. Attempting to generate it. " \
             "Run 'bundle exec asktive_record:setup' for robust schema handling."

        return fallback_schema_from_rails(path) if defined?(Rails)

        raise ConfigurationError,
              "Database schema file not found at #{path}. AsktiveRecord needs schema context. " \
              "Run in a Rails environment or ensure the schema file is present."
      end

      def fallback_schema_from_rails(path)
        system("bin/rails db:schema:dump")
        return File.read(path) if File.exist?(path)

        alt_path = "db/structure.sql"
        return use_alternative_schema(alt_path) if File.exist?(alt_path)

        raise ConfigurationError,
              "Database schema file not found at #{path} or #{alt_path} even after attempting to dump. " \
              "Please run asktive_record:setup or configure the correct path."
      end

      def use_alternative_schema(path)
        puts "Using schema from #{path}"
        File.read(path)
      end

      def resolve_model(provided_model)
        return provided_model if provided_model
        return ApplicationRecord if defined?(Rails) && defined?(ApplicationRecord)

        self
      end
    end
  end
end
