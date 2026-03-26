# frozen_string_literal: true

require "openai"
require "asktive_record/prompt"
require "asktive_record/log"

module AsktiveRecord
  # Service class for interacting with the LLM API to generate SQL queries
  # and answer questions based on the generated queries and database responses.
  class LlmService
    attr_reader :configuration

    def initialize(configuration)
      @configuration = configuration
      @client = nil

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
      llm_response = call_llm(prompt)
      extract_answer(llm_response)
    rescue OpenAI::Error => e
      raise ApiError, "OpenAI API error: #{e.message}"
    rescue StandardError => e
      raise QueryGenerationError, "Failed to generate SQL query: #{e.message}"
    end

    def client
      @client ||= OpenAI::Client.new(access_token: configuration.llm_api_key)
    end

    def call_llm(prompt)
      client.chat(
        parameters: {
          model: configuration.llm_model_name || "gpt-4o-mini",
          messages: [{ role: "user", content: prompt }],
          temperature: 0.2,
          max_tokens: 250
        }
      )
    end

    def extract_answer(response)
      response.dig("choices", 0, "message", "content")&.strip
    end

    def generate_and_validate_sql(prompt)
      raw_sql = fetch_sql_from_llm(prompt)
      validate_sql_response!(raw_sql)
      clean_sql(raw_sql)
    rescue OpenAI::Error => e
      raise ApiError, "OpenAI API error: #{e.message}"
    rescue StandardError => e
      raise QueryGenerationError, "Failed to generate SQL query: #{e.message}"
    end

    def fetch_sql_from_llm(prompt)
      response = call_llm(prompt)
      response.dig("choices", 0, "message", "content")&.strip
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
