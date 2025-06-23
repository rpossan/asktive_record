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

        @schema_content ||= load_schema_content
        ensure_schema_is_not_empty!

        llm_service = AsktiveRecord::LlmService.new(AsktiveRecord.configuration)
        current_table_name = respond_to?(:table_name) ? table_name : name.downcase.pluralize

        raw_sql = llm_service.generate_sql(natural_language_query, @schema_content, current_table_name)

        AsktiveRecord::Query.new(natural_language_query, raw_sql, self)
      end

      private

      def ensure_api_key_configured!
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
        dump_successful = true # Assume success if skipping
        unless AsktiveRecord.configuration.skip_dump_schema
          dump_successful = system("bin/rails db:schema:dump")
        end

        return File.read(path) if File.exist?(path)

        alt_path = "db/structure.sql"
        return use_alternative_schema(alt_path) if File.exist?(alt_path)

        message = if !dump_successful
                    "Failed to dump schema and no existing schema file found."
                  else
                    "Database schema file not found at #{path} or #{alt_path} even after attempting to dump. " \
                    "Please run asktive_record:setup or configure the correct path."
                  end
        raise ConfigurationError, message
      end

      def use_alternative_schema(path)
        puts "Using schema from #{path}"
        File.read(path)
      end

      def ensure_schema_is_not_empty!
        return unless @schema_content.to_s.strip.empty?

        raise ConfigurationError,
              "Schema content is empty. Cannot proceed without database schema context."
      end
    end
  end
end
