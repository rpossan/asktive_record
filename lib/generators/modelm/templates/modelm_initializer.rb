# Modelm Initializer
Modelm.configure do |config|
  # === LLM Provider ===
  # Specify the LLM provider to use. Default is :openai
  # Supported providers: :openai (more can be added in the future)
  # config.llm_provider = :openai

  # === LLM API Key ===
  # Set your API key for the chosen LLM provider.
  # It is strongly recommended to use environment variables for sensitive data.
  # For example, for OpenAI:
  # config.llm_api_key = ENV["OPENAI_API_KEY"]
  config.llm_api_key = "YOUR_OPENAI_API_KEY_HERE"

  # === LLM Model Name ===
  # Specify the model name for the LLM provider if applicable.
  # For OpenAI, default is "gpt-3.5-turbo". Other models like "gpt-4" can be used.
  # config.llm_model_name = "gpt-3.5-turbo"

  # === Database Schema Path ===
  # Path to your Rails application's schema file (usually schema.rb or structure.sql).
  # This is used by the `modelm:setup` command to provide context to the LLM.
  # Default is "db/schema.rb".
  # config.db_schema_path = "db/schema.rb"
end

