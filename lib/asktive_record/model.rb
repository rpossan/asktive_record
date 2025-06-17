# frozen_string_literal: true

require "asktive_record/llm_service"

module AsktiveRecord
  module Model
    # Provides class-level methods for AsktiveRecord models, enabling natural language queries and configuration checks.
    module ClassMethods
      def asktive_record
        return if AsktiveRecord.configuration

        raise ConfigurationError,
              "AsktiveRecord is not configured. Please run the installer and " \
              "ensure config/initializers/asktive_record.rb is set up."
      end

      def ask(natural_language_query)
        ensure_api_key_configured!

        schema_content = load_schema
        raise ConfigurationError, "Schema content is empty." if schema_content.to_s.strip.empty?

        llm_service = AsktiveRecord::LlmService.new(AsktiveRecord.configuration)
        current_table_name = respond_to?(:table_name) ? table_name : name.downcase.pluralize

        raw_sql = llm_service.generate_sql(natural_language_query, schema_content, current_table_name)

        AsktiveRecord::Query.new(natural_language_query, raw_sql, self)
      end

      private

      def ensure_api_key_configured!
        return if AsktiveRecord.configuration&.llm_api_key

        raise ConfigurationError, "LLM API key is not configured for AsktiveRecord."
      end

      def load_schema
        schema_path = AsktiveRecord.configuration.db_schema_path
        return File.read(schema_path) if File.exist?(schema_path)

        puts "Schema file not found at #{schema_path}. Attempting to generate it."
        try_dump_schema(schema_path) || try_structure_sql || raise_schema_error(schema_path)
      rescue SystemCallError => e
        raise ConfigurationError, "Error reading schema file at #{schema_path}: #{e.message}"
      end

      def try_dump_schema(schema_path)
        return unless defined?(Rails) && !AsktiveRecord.configuration.skip_dump_schema

        system("bin/rails db:schema:dump")
        File.exist?(schema_path) ? File.read(schema_path) : nil
      end

      def try_structure_sql
        path = "db/structure.sql"
        return unless File.exist?(path)

        puts "Using schema from #{path}"
        File.read(path)
      end

      def raise_schema_error(schema_path)
        raise ConfigurationError, <<~MSG.strip
          Database schema file not found at #{schema_path} or db/structure.sql.
          Please run `asktive_record:setup` or configure the correct path.
        MSG
      end
    end
  end
end
