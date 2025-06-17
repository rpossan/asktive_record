# frozen_string_literal: true

module AsktiveRecord
  # Configuration class for AsktiveRecord
  # This class holds the configuration settings for the LLM provider, API key, model name
  # and database schema path.
  class Configuration
    attr_accessor :llm_provider, :llm_api_key, :llm_model_name, :db_schema_path, :skip_dump_schema

    def initialize
      @llm_provider = :openai # Default LLM provider
      @llm_api_key = nil
      @llm_model_name = "gpt-3.5-turbo" # Default model for OpenAI
      @db_schema_path = "db/schema.rb" # Default path for Rails schema file
      @skip_dump_schema = false # Default is to not skip schema dump
    end
  end
end
