# frozen_string_literal: true

require "asktive_record/llm_service"
require "debug"

module AsktiveRecord
  module Service
    module ClassMethods
      def ask(natural_language_query, options = {})
        # binding.break
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

        # For service-based queries, we don't specify a target table in the prompt
        # The LLM will determine the appropriate tables based on the query and schema
        target_table = options[:table_name] || "any"

        # Generate SQL using the enhanced LLM service that supports multi-table queries
        raw_sql = llm_service.generate_sql_for_service(natural_language_query, schema_content, target_table)

        # For service-based queries, we need to determine the appropriate model for execution
        # If a specific model is provided in options, use that
        target_model = options[:model]

        # If no model is specified but we're in a Rails environment, use ApplicationRecord
        target_model = ApplicationRecord if target_model.nil? && defined?(Rails) && defined?(ApplicationRecord)

        # If still no model, use the service class itself (which may not have find_by_sql)
        target_model ||= self

        AsktiveRecord::Query.new(natural_language_query, raw_sql, target_model)
      end
    end
  end
end
