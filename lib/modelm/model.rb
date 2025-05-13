# frozen_string_literal: true
require "modelm/llm_service" # Ensure LlmService is available

module Modelm
  module Model
    module ClassMethods
      def modelm
        # This method is called in the Rails model to include Modelm's functionality.
        # It can be used for any specific setup related to the model if needed in the future.
        unless Modelm.configuration
          raise ConfigurationError, "Modelm is not configured. Please run the installer and ensure config/initializers/modelm.rb is set up."
        end
      end

      def ask(natural_language_query)
        unless Modelm.configuration&.llm_api_key
          raise ConfigurationError, "LLM API key is not configured for Modelm."
        end

        schema_path = Modelm.configuration.db_schema_path
        schema_content = nil

        begin
          if File.exist?(schema_path)
            schema_content = File.read(schema_path)
          else
            # Attempt to use rails db:schema:dump if schema file is not found, as a fallback
            # This is more relevant for the `modelm:setup` task but can be a safety net here.
            puts "Schema file not found at #{schema_path}. Attempting to generate it. Run 'bundle exec modelm:setup' for robust schema handling."
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
                    raise ConfigurationError, "Database schema file not found at #{schema_path} or #{alt_schema_path} even after attempting to dump. Please run modelm:setup or configure the correct path."
                end
              end
            else
              raise ConfigurationError, "Database schema file not found at #{schema_path}. Modelm needs schema context. Run in a Rails environment or ensure the schema file is present."
            end
          end
        rescue SystemCallError => e
          raise ConfigurationError, "Error reading schema file at #{schema_path}: #{e.message}"
        end

        raise ConfigurationError, "Schema content is empty. Cannot proceed without database schema context." if schema_content.to_s.strip.empty?

        llm_service = Modelm::LlmService.new(Modelm.configuration)
        
        # Determine table name. In Rails, self.table_name would work directly.
        # For broader compatibility or if used outside AR, this might need adjustment.
        current_table_name = self.respond_to?(:table_name) ? self.table_name : self.name.downcase.pluralize

        raw_sql = llm_service.generate_sql(natural_language_query, schema_content, current_table_name)

        Modelm::Query.new(raw_sql, self)
      end
    end
  end
end

