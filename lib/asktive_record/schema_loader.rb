# frozen_string_literal: true

require "asktive_record/log"

module AsktiveRecord
  # SchemaLoader provides shared schema loading functionality used by both
  # Model::ClassMethods and Service::ClassMethods. It handles reading schema files,
  # falling back to structure.sql, and providing clear error messages.
  module SchemaLoader
    # Loads the database schema content from the configured path.
    # Falls back to db/structure.sql if the primary schema file is not found.
    #
    # @return [String] the schema content
    # @raise [ConfigurationError] if no schema file is found or content is empty
    def load_schema_content
      path = AsktiveRecord.configuration.db_schema_path
      return File.read(path) if File.exist?(path)

      attempt_schema_fallback(path)
    rescue SystemCallError => e
      raise ConfigurationError, "Error reading schema file at #{path}: #{e.message}"
    end

    # Validates that the schema content is not empty.
    #
    # @param schema_content [String] the schema content to validate
    # @raise [ConfigurationError] if schema content is blank
    def ensure_schema_is_not_empty!(schema_content)
      return unless schema_content.to_s.strip.empty?

      raise ConfigurationError,
            "Schema content is empty. Cannot proceed without database schema context."
    end

    # Validates that the LLM API key is configured.
    #
    # @raise [ConfigurationError] if the API key is not set
    def validate_llm_api_key!
      return if AsktiveRecord.configuration&.llm_api_key

      raise ConfigurationError, "LLM API key is not configured for AsktiveRecord."
    end

    private

    def attempt_schema_fallback(path)
      AsktiveRecord::Log.warn(
        "Schema file not found at #{path}. " \
        "Run 'bundle exec rails generate asktive_record:setup' for robust schema handling."
      )

      alt_path = "db/structure.sql"
      if File.exist?(alt_path)
        AsktiveRecord::Log.info("Using schema from #{alt_path}")
        return File.read(alt_path)
      end

      raise ConfigurationError,
            "Database schema file not found at #{path}. AsktiveRecord needs schema context. " \
            "Ensure the schema file is present or configure the correct path."
    end
  end
end
