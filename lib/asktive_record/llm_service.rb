# frozen_string_literal: true

require "asktive_record/prompt"
require "asktive_record/log"

module AsktiveRecord
  # Service class for interacting with the LLM API to generate SQL queries
  # and answer questions based on the generated queries and database responses.
  # Uses the adapter pattern to support multiple LLM providers.
  class LlmService
    attr_reader :configuration

    def initialize(configuration)
      @configuration = configuration
      @adapter = nil

      return if @configuration&.llm_api_key

      raise ConfigurationError,
            "LLM API key is not configured. Please set it in config/initializers/asktive_record.rb" \
            " or via environment variable."
    end

    # Placeholder for schema upload/management with the LLM if needed for more advanced scenarios.
    # For instance, if using OpenAI Assistants API or fine-tuning.
    # For now, the schema is passed with each query.
    def upload_schema(_schema_string)
      AsktiveRecord::Log.info("Schema upload functionality is a placeholder for now.")
      true
    end

    def answer(question, query, response)
      AsktiveRecord::Log.info("Answering question: #{question}")
      AsktiveRecord::Log.debug("Generated SQL query: #{query}")
      AsktiveRecord::Log.debug("Response from database: #{response.inspect}")
      answer_as_human(question, query, response)
    end

    # Method for model-specific queries
    def generate_sql(natural_language_query, schema_string, table_name)
      prompt = Prompt.as_sql_generator_for_model(
        natural_language_query,
        schema_string,
        table_name
      )

      generate_and_validate_sql(prompt)
    end

    # Method for service-class-based queries that can target any table
    def generate_sql_for_service(natural_language_query, schema_string, _target_table = "any")
      prompt = Prompt.as_sql_generator(natural_language_query, schema_string)
      generate_and_validate_sql(prompt)
    end

    private

    def answer_as_human(question, query, response)
      prompt = Prompt.as_human_answerer(question, query, response)
      adapter.chat(prompt, llm_options)
    rescue ApiError
      raise
    rescue StandardError => e
      raise QueryGenerationError, "Failed to generate SQL query: #{e.message}"
    end

    def adapter
      @adapter ||= configuration.resolved_adapter
    end

    def llm_options
      {
        temperature: configuration.temperature || 0.2,
        max_tokens: configuration.max_tokens || 250
      }
    end

    def generate_and_validate_sql(prompt)
      raw_sql = adapter.chat(prompt, llm_options)
      validate_sql_response!(raw_sql)
      clean_sql(raw_sql)
    rescue ApiError
      raise
    rescue StandardError => e
      raise QueryGenerationError, "Failed to generate SQL query: #{e.message}"
    end

    def validate_sql_response!(raw_sql)
      raise QueryGenerationError, "LLM did not return a SQL query." if raw_sql.nil? || raw_sql.empty?

      return if raw_sql.strip.match?(/\ASELECT\b/i)

      raise QueryGenerationError, "LLM generated a non-SELECT query: #{raw_sql}"
    end

    def clean_sql(sql)
      sql.gsub(/;\s*\z/, "").strip
    end
  end
end
