# frozen_string_literal: true

require "asktive_record/llm_service"

module AsktiveRecord
  module Model
    module ClassMethods
      def asktive_record
        # This method is called in the Rails model to include AsktiveRecord's functionality.
        # It can be used for any specific setup related to the model if needed in the future.
        return if AsktiveRecord.configuration

        raise ConfigurationError,
              "AsktiveRecord is not configured. Please run the installer and ensure config/initializers/asktive_record.rb is set up."
      end

      def ask(natural_language_query)
        unless AsktiveRecord.configuration&.llm_api_key
          raise ConfigurationError,
                "LLM API key is not configured for AsktiveRecord."
        end

        schema_path = AsktiveRecord.configuration.db_schema_path
        schema_content = nil

        begin
          if File.exist?(schema_path)
            schema_content = File.read(schema_path)
          else
            # Attempt to use rails db:schema:dump if schema file is not found, as a fallback
            # This is more relevant for the `asktive_record:setup` task but can be a safety net here.
            puts "Schema file not found at #{schema_path}. Attempting to generate it. Run 'bundle exec asktive_record:setup' for robust schema handling."
            if defined?(Rails)
              system("bin/rails db:schema:dump")
              if File.exist?(schema_path) # Check again after dump
                schema_content = File.read(schema_path)
              else
                # Check for structure.sql as an alternative if schema_format is :sql
                alt_schema_path = "db/structure.sql"
                if File.exist?(alt_schema_path)
                  schema_content = File.read(alt_schema_path)
                  puts "Using schema from #{alt_schema_path}"
                else
                  raise ConfigurationError,
                        "Database schema file not found at #{schema_path} or #{alt_schema_path} even after attempting to dump. Please run asktive_record:setup or configure the correct path."
                end
              end
            else
              raise ConfigurationError,
                    "Database schema file not found at #{schema_path}. AsktiveRecord needs schema context. Run in a Rails environment or ensure the schema file is present."
            end
          end
        rescue SystemCallError => e
          raise ConfigurationError, "Error reading schema file at #{schema_path}: #{e.message}"
        end

        if schema_content.to_s.strip.empty?
          raise ConfigurationError,
                "Schema content is empty. Cannot proceed without database schema context."
        end

        llm_service = AsktiveRecord::LlmService.new(AsktiveRecord.configuration)

        # Determine table name. In Rails, self.table_name would work directly.
        # For broader compatibility or if used outside AR, this might need adjustment.
        current_table_name = respond_to?(:table_name) ? table_name : name.downcase.pluralize

        # Use the original model-specific method for model-based queries
        raw_sql = llm_service.generate_sql(natural_language_query, schema_content, current_table_name)

        AsktiveRecord::Query.new(natural_language_query, raw_sql, self)
      end
    end
  end
end
