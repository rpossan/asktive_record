# frozen_string_literal: true

require "openai"
require "asktive_record/prompt"

module AsktiveRecord
  # Service class for interacting with the LLM API to generate SQL queries
  # and answer questions based on the generated queries and database responses.
  class LlmService
    attr_reader :configuration

    def initialize(configuration)
      @configuration = configuration
      return if @configuration&.llm_api_key

      raise ConfigurationError,
            "LLM API key is not configured. Please set it in config/initializers/asktive_record.rb\
 or via environment variable."
    end

    # Placeholder for schema upload/management with the LLM if needed for more advanced scenarios
    # For instance, if using OpenAI Assistants API or fine-tuning.
    # For now, the schema is passed with each query.
    def upload_schema(_schema_string)
      # This could be used to upload schema to a vector store or a fine-tuning dataset in the future.
      puts "Schema upload functionality is a placeholder for now."
      true
    end

    def answer(question, query, response)
      puts "Answering question: #{question}"
      puts "Generated SQL query: #{query}"
      puts "Response from database: #{response.inspect}"
      answer_as_human(question, query, response)
    end

    # Original method for model-specific queries
    def generate_sql(natural_language_query, schema_string, table_name)
      client = OpenAI::Client.new(access_token: configuration.llm_api_key)

      prompt = Prompt.as_sql_generator_for_model(
        natural_language_query,
        schema_string,
        table_name
      )

      generate_and_validate_sql(client, prompt)
    end

    # New method for service-class-based queries that can target any table
    def generate_sql_for_service(natural_language_query, schema_string, _target_table = "any")
      client = OpenAI::Client.new(access_token: configuration.llm_api_key)
      prompt = Prompt.as_sql_generator(natural_language_query, schema_string)
      generate_and_validate_sql(client, prompt)
    end

    private

    def answer_as_human(question, query, response)
      prompt = Prompt.as_human_answerer(question, query, response)
      client = build_client
      llm_response = call_llm(client, prompt)
      extract_answer(llm_response)
    rescue OpenAI::Error => e
      raise ApiError, "OpenAI API error: #{e.message}"
    rescue StandardError => e
      raise QueryGenerationError, "Failed to generate SQL query: #{e.message}"
    end

    def build_client
      OpenAI::Client.new(access_token: configuration.llm_api_key)
    end

    def call_llm(client, prompt)
      client.chat(
        parameters: {
          model: configuration.llm_model_name || "gpt-3.5-turbo",
          messages: [{ role: "user", content: prompt }],
          temperature: 0.2,
          max_tokens: 250
        }
      )
    end

    def extract_answer(response)
      response.dig("choices", 0, "message", "content")&.strip
    end

    def generate_and_validate_sql(client, prompt)
      raw_sql = fetch_sql_from_llm(client, prompt)
      validate_sql_response!(raw_sql)
      sanitize_sql(raw_sql)
    rescue OpenAI::Error => e
      raise ApiError, "OpenAI API error: #{e.message}"
    rescue StandardError => e
      raise QueryGenerationError, "Failed to generate SQL query: #{e.message}"
    end

    def fetch_sql_from_llm(client, prompt)
      response = client.chat(
        parameters: {
          model: configuration.llm_model_name || "gpt-3.5-turbo",
          messages: [{ role: "user", content: prompt }],
          temperature: 0.2,
          max_tokens: 250
        }
      )
      response.dig("choices", 0, "message", "content")&.strip
    end

    def validate_sql_response!(raw_sql)
      raise QueryGenerationError, "LLM did not return a SQL query." if raw_sql.nil? || raw_sql.empty?

      return if raw_sql.downcase.start_with?("select")

      raise QueryGenerationError, "LLM generated a non-SELECT query: #{raw_sql}"
    end

    def sanitize_sql(sql)
      sql.chomp(";")
    end
  end
end
