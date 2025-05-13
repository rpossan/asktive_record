# frozen_string_literal: true

module Modelm
  class Configuration
    attr_accessor :llm_provider, :llm_api_key, :llm_model_name, :db_schema_path

    def initialize
      @llm_provider = :openai # Default LLM provider
      @llm_api_key = nil
      @llm_model_name = "gpt-3.5-turbo" # Default model for OpenAI
      @db_schema_path = "db/schema.rb" # Default path for Rails schema file
    end
  end
end

