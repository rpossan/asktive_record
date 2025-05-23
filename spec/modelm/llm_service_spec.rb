# frozen_string_literal: true

require "spec_helper"
require "modelm/llm_service"
require "modelm/configuration"
require "modelm/error"

RSpec.describe Modelm::LlmService do
  let(:api_key) { "test_api_key" }
  let(:configuration) do
    config = Modelm::Configuration.new
    config.llm_api_key = api_key
    config.llm_model_name = "gpt-3.5-turbo-test"
    config
  end
  let(:service) { Modelm::LlmService.new(configuration) }
  let(:openai_client_double) { instance_double(OpenAI::Client) }

  before do
    allow(OpenAI::Client).to receive(:new).with(access_token: api_key).and_return(openai_client_double)
  end

  describe "#initialize" do
    it "initializes with a valid configuration" do
      expect(service.configuration).to eq(configuration)
    end

    it "raises ConfigurationError if API key is missing" do
      configuration.llm_api_key = nil
      expect { Modelm::LlmService.new(configuration) }.to raise_error(Modelm::ConfigurationError, "LLM API key is not configured. Please set it in config/initializers/modelm.rb or via environment variable.")
    end
  end

  describe "#generate_sql" do
    let(:natural_language_query) { "show me all users" }
    let(:schema_string) { "CREATE TABLE users (id INTEGER, name VARCHAR(255));" }
    let(:table_name) { "users" }
    let(:expected_sql) { "SELECT * FROM users" }
    let(:chat_response) do
      {
        "choices" => [
          {
            "message" => {
              "role" => "assistant",
              "content" => "#{expected_sql};"
            }
          }
        ]
      }
    end

    it "generates SQL successfully for a valid query" do
      allow(openai_client_double).to receive(:chat).and_return(chat_response)
      sql = service.generate_sql(natural_language_query, schema_string, table_name)
      expect(sql).to eq(expected_sql) # Semicolon should be chomped
    end

    it "constructs the correct prompt" do
      expected_prompt = <<~PROMPT
        You are an expert SQL generator. Your task is to convert a natural language query into a SQL query for a database with the following schema.
        Only generate SELECT queries. Do not generate any INSERT, UPDATE, DELETE, DROP, or other DDL/DML statements.
        The query should be for the table: #{table_name}.

        Database Schema:
        ```sql
        #{schema_string}
        ```

        Natural Language Query: "#{natural_language_query}"

        Based on the schema and the natural language query, provide only the SQL query as a single line of text, without any explanation or surrounding text.
        For example, if the query is "show me all users", and the table is `users`, the output should be:
        SELECT * FROM users;
        If the query is "find the last 5 registered users", the output should be:
        SELECT * FROM users ORDER BY created_at DESC LIMIT 5;

        SQL Query:
      PROMPT

      expect(openai_client_double).to receive(:chat).with(
        parameters: {
          model: "gpt-3.5-turbo-test",
          messages: [{ role: "user", content: expected_prompt }],
          temperature: 0.2,
          max_tokens: 250
        }
      ).and_return(chat_response)
      service.generate_sql(natural_language_query, schema_string, table_name)
    end

    it "raises QueryGenerationError if LLM returns a non-SELECT query" do
      non_select_response = {
        "choices" => [{"message" => {"content" => "DROP TABLE users;"}}]
      }
      allow(openai_client_double).to receive(:chat).and_return(non_select_response)
      expect { service.generate_sql(natural_language_query, schema_string, table_name) }.to raise_error(Modelm::QueryGenerationError, /LLM generated a non-SELECT query/)
    end

    it "raises QueryGenerationError if LLM returns no content" do
      empty_response = {
        "choices" => [{"message" => {"content" => ""}}]
      }
      allow(openai_client_double).to receive(:chat).and_return(empty_response)
      expect { service.generate_sql(natural_language_query, schema_string, table_name) }.to raise_error(Modelm::QueryGenerationError, /LLM did not return a SQL query/)
    end

    it "raises ApiError on OpenAI API errors" do
      allow(openai_client_double).to receive(:chat).and_raise(OpenAI::Error.new("API connection error"))
      expect { service.generate_sql(natural_language_query, schema_string, table_name) }.to raise_error(Modelm::ApiError, "OpenAI API error: API connection error")
    end

    it "raises QueryGenerationError on other unexpected errors during generation" do
      allow(openai_client_double).to receive(:chat).and_raise(StandardError.new("Unexpected issue"))
      expect { service.generate_sql(natural_language_query, schema_string, table_name) }.to raise_error(Modelm::QueryGenerationError, "Failed to generate SQL query: Unexpected issue")
    end
  end

  describe "#upload_schema" do
    it "is a placeholder and returns true" do
      # As this is a placeholder, we just check it runs without error and returns true.
      # We can also check the output if it's important for user feedback.
      expect(STDOUT).to receive(:puts).with("Schema upload functionality is a placeholder for now.")
      expect(service.upload_schema("schema_string")).to be true
    end
  end
end

