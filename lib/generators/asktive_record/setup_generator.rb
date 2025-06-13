require "rails/generators/base"
require "debug"

module AsktiveRecord
  module Generators
    class SetupGenerator < Rails::Generators::Base
      desc "Sets up AsktiveRecord by reading the database schema and preparing it for the LLM."

      def perform_setup
        # In a Rails application context, this would run `rails db:schema:dump`
        # and then potentially upload or process the schema for the LLM.
        # For now, we'll simulate this and inform the user.

        schema_path = AsktiveRecord.configuration&.db_schema_path || "db/schema.rb"
        schema_content = nil

        if defined?(Rails)
          begin
            puts "Attempting to dump database schema using 'rails db:schema:dump'..."
            # This command will write to db/schema.rb or db/structure.sql
            # depending on Rails.application.config.active_record.schema_format
            system("bin/rails db:schema:dump")

            # Try to read the schema file specified in the configuration
            if File.exist?(schema_path)
              schema_content = File.read(schema_path)
              puts "Successfully read schema from #{schema_path}."
            else
              # Fallback if the primary schema_path doesn't exist, try structure.sql
              structure_sql_path = "db/structure.sql"
              if File.exist?(structure_sql_path)
                schema_content = File.read(structure_sql_path)
                puts "Successfully read schema from #{structure_sql_path}."
              else
                puts "Could not find schema file at #{schema_path} or #{structure_sql_path} after dump."
              end
            end
          rescue StandardError => e
            puts "Failed to execute 'rails db:schema:dump' or read schema: #{e.message}"
            puts "Please ensure you are in a Rails application directory and the database is configured."
            return
          end
        else
          puts "This command should be run within a Rails application."
          puts "Simulating schema reading. In a real app, ensure '#{schema_path}' exists or is configured."
          # Simulate reading if not in Rails for standalone testing of the generator
          if File.exist?(schema_path)
            schema_content = File.read(schema_path)
            puts "Successfully read schema from #{schema_path} (simulated)."
          else
            puts "Schema file not found at #{schema_path} (simulated)."
          end
        end

        if schema_content
          # Here, you would typically send the schema_content to the LLM service
          # or store it for later use by the LLM.
          puts "Database schema obtained. Length: #{schema_content.length} characters."
          puts "Next step would be to process and provide this schema to the configured LLM."
          # For example:
          # LlmService.new(AsktiveRecord.configuration).upload_schema(schema_content)
        else
          puts "Could not obtain database schema. LLM will not have schema context."
        end

        puts "AsktiveRecord setup process complete."
        puts "Ensure your LLM API key and other configurations are set in config/initializers/asktive_record.rb"
      end
    end
  end
end
