# frozen_string_literal: true

require "rails/generators/base"

module AsktiveRecord
  module Generators
    # SetupGenerator is a Rails generator that sets up AsktiveRecord by reading the
    # database schema and preparing it for the LLM. It attempts to dump the schema
    # using `rails db:schema:dump` and reads the schema file or structure.sql
    # to provide the schema context to the LLM.
    class SetupGenerator < Rails::Generators::Base
      desc "Sets up AsktiveRecord by reading the database schema and preparing it for the LLM."

      def perform_setup
        schema_path = AsktiveRecord.configuration&.db_schema_path || "db/schema.rb"
        schema_content = defined?(Rails) ? dump_and_read_schema(schema_path) : simulate_schema_read(schema_path)

        if schema_content
          puts "Database schema obtained. Length: #{schema_content.length} characters."
          puts "Next step would be to process and provide this schema to the configured LLM."
        else
          puts "Could not obtain database schema. LLM will not have schema context."
        end

        puts "AsktiveRecord setup process complete."
        puts "Ensure your LLM API key and other configurations are set in config/initializers/asktive_record.rb"
      end

      private

      def dump_and_read_schema(schema_path)
        puts "Attempting to dump database schema using 'rails db:schema:dump'..."
        system("bin/rails db:schema:dump") unless AsktiveRecord.configuration.skip_dump_schema
        read_schema_file(schema_path) || read_structure_sql || schema_not_found_message(schema_path)
      rescue StandardError => e
        puts "Failed to execute 'rails db:schema:dump' or read schema: #{e.message}"
        puts "Please ensure you are in a Rails application directory and the database is configured."
        nil
      end

      def simulate_schema_read(schema_path)
        puts "This command should be run within a Rails application."
        puts "Simulating schema reading. In a real app, ensure '#{schema_path}' exists or is configured."

        if File.exist?(schema_path)
          puts "Successfully read schema from #{schema_path} (simulated)."
          File.read(schema_path)
        else
          puts "Schema file not found at #{schema_path} (simulated)."
          nil
        end
      end

      def read_schema_file(path)
        return unless File.exist?(path)

        puts "Successfully read schema from #{path}."
        File.read(path)
      end

      def read_structure_sql
        path = "db/structure.sql"
        return unless File.exist?(path)

        puts "Successfully read schema from #{path}."
        File.read(path)
      end

      def schema_not_found_message(schema_path)
        puts "Could not find schema file at #{schema_path} or db/structure.sql after dump."
        nil
      end
    end
  end
end
