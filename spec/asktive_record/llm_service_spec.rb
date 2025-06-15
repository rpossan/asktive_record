# frozen_string_literal: true

require "./spec/spec_helper"
require "asktive_record/llm_service"
require "asktive_record/configuration"
require "asktive_record/error"

RSpec.describe AsktiveRecord::LlmService do
  let(:api_key) { "test_api_key" }
  let(:configuration) do
    config = AsktiveRecord::Configuration.new
    config.llm_api_key = api_key
    config.llm_model_name = "gpt-3.5-turbo-test"
    config
  end
  let(:service) { AsktiveRecord::LlmService.new(configuration) }
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
      expect do
        AsktiveRecord::LlmService.new(configuration)
      end.to raise_error(AsktiveRecord::ConfigurationError,
                         "LLM API key is not configured. Please set it in config/initializers/asktive_record.rb or via environment variable.")
    end
  end

  describe "#generate_sql_for_service" do
    let(:natural_language_query) { "show me products with their categories" }
    let(:schema_string) do
      <<~SQL
        CREATE TABLE products (id INTEGER, name VARCHAR(255), category_id INTEGER, price DECIMAL);
        CREATE TABLE categories (id INTEGER, name VARCHAR(255));
      SQL
    end
    let(:target_table) { "any" }
    let(:expected_sql) do
      "SELECT products.*, categories.name as category_name FROM products JOIN categories ON products.category_id = categories.id"
    end
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

    it "generates SQL successfully for a valid service query" do
      allow(openai_client_double).to receive(:chat).and_return(chat_response)
      sql = service.generate_sql_for_service(natural_language_query, schema_string, target_table)
      expect(sql).to eq(expected_sql)
    end

    it "constructs the correct prompt for service queries" do
      expected_prompt = <<~PROMPT
        You are an expert SQL generator. Your task is to convert a natural language query into a SQL query for a database with the following schema.
        Only generate SELECT queries. Do not generate any INSERT, UPDATE, DELETE, DROP, or other DDL/DML statements.

        Database Schema:
        ```sql
        #{schema_string}
        ```

        Natural Language Query: "#{natural_language_query}"

        Based on the schema and the natural language query, provide only the SQL query as a single line of text, without any explanation or surrounding text.
        You should determine the appropriate table(s) to query from the schema and the natural language query.
        Use JOINs when necessary to query data across multiple tables.

        Examples:
        - If the query is "show me all users", the output should be: SELECT * FROM users;
        - If the query is "find the last 5 registered users", the output should be: SELECT * FROM users ORDER BY created_at DESC LIMIT 5;
        - If the query is "show me products with their categories", the output might be: SELECT products.*, categories.name as category_name FROM products JOIN categories ON products.category_id = categories.id;
        - If the query is "which is the cheapest product", the output might be: SELECT * FROM products ORDER BY price ASC LIMIT 1;

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
      service.generate_sql_for_service(natural_language_query, schema_string, target_table)
    end

    it "raises QueryGenerationError if LLM returns a non-SELECT query" do
      non_select_response = {
        "choices" => [{ "message" => { "content" => "DROP TABLE products;" } }]
      }
      allow(openai_client_double).to receive(:chat).and_return(non_select_response)
      expect do
        service.generate_sql_for_service(natural_language_query, schema_string, target_table)
      end.to raise_error(AsktiveRecord::QueryGenerationError, /LLM generated a non-SELECT query/)
    end

    it "raises QueryGenerationError if LLM returns no content" do
      empty_response = {
        "choices" => [{ "message" => { "content" => "" } }]
      }
      allow(openai_client_double).to receive(:chat).and_return(empty_response)
      expect do
        service.generate_sql_for_service(natural_language_query, schema_string, target_table)
      end.to raise_error(AsktiveRecord::QueryGenerationError, /LLM did not return a SQL query/)
    end

    it "raises ApiError on OpenAI API errors" do
      allow(openai_client_double).to receive(:chat).and_raise(OpenAI::Error.new("API connection error"))
      expect do
        service.generate_sql_for_service(natural_language_query, schema_string, target_table)
      end.to raise_error(AsktiveRecord::ApiError, "OpenAI API error: API connection error")
    end

    it "raises QueryGenerationError on other unexpected errors during generation" do
      allow(openai_client_double).to receive(:chat).and_raise(StandardError.new("Unexpected issue"))
      expect do
        service.generate_sql_for_service(natural_language_query, schema_string, target_table)
      end.to raise_error(AsktiveRecord::QueryGenerationError, "Failed to generate SQL query: Unexpected issue")
    end

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
        "choices" => [{ "message" => { "content" => "DROP TABLE users;" } }]
      }
      allow(openai_client_double).to receive(:chat).and_return(non_select_response)
      expect do
        service.generate_sql(natural_language_query, schema_string,
                             table_name)
      end.to raise_error(AsktiveRecord::QueryGenerationError, /LLM generated a non-SELECT query/)
    end

    it "raises QueryGenerationError if LLM returns no content" do
      empty_response = {
        "choices" => [{ "message" => { "content" => "" } }]
      }
      allow(openai_client_double).to receive(:chat).and_return(empty_response)
      expect do
        service.generate_sql(natural_language_query, schema_string,
                             table_name)
      end.to raise_error(AsktiveRecord::QueryGenerationError, /LLM did not return a SQL query/)
    end

    it "raises ApiError on OpenAI API errors" do
      allow(openai_client_double).to receive(:chat).and_raise(OpenAI::Error.new("API connection error"))
      expect do
        service.generate_sql(natural_language_query, schema_string,
                             table_name)
      end.to raise_error(AsktiveRecord::ApiError, "OpenAI API error: API connection error")
    end

    it "raises QueryGenerationError on other unexpected errors during generation" do
      allow(openai_client_double).to receive(:chat).and_raise(StandardError.new("Unexpected issue"))
      expect do
        service.generate_sql(natural_language_query, schema_string,
                             table_name)
      end.to raise_error(AsktiveRecord::QueryGenerationError, "Failed to generate SQL query: Unexpected issue")
    end
  end

  describe "#upload_schema" do
    it "is a placeholder and returns true" do
      # As this is a placeholder, we just check it runs without error and returns true.
      # We can also check the output if it's important for user feedback.
      expect($stdout).to receive(:puts).with("Schema upload functionality is a placeholder for now.")
      expect(service.upload_schema("schema_string")).to be true
    end
  end
  describe "#answer" do
    let(:question) { "Quantos usuários existem?" }
    let(:query) { "SELECT COUNT(*) FROM users" }
    let(:db_response) { [{ "count" => 5 }] }
    let(:human_answer) { "Existem 5 usuários no banco de dados." }

    before do
      allow(service).to receive(:answer_as_human).with(question, query, db_response).and_return(human_answer)
    end

    it "calls answer_as_human with the correct arguments and returns its result" do
      expect(service).to receive(:answer_as_human).with(question, query, db_response)
      expect(service.answer(question, query, db_response)).to eq(human_answer)
    end

    it "prints debug information to stdout" do
      expect($stdout).to receive(:puts).with("Answering question: #{question}")
      expect($stdout).to receive(:puts).with("Generated SQL query: #{query}")
      expect($stdout).to receive(:puts).with("Response from database: #{db_response.inspect}")
      service.answer(question, query, db_response)
    end
  end

  describe "#answer_as_human" do
    let(:question) { "Quantos usuários existem?" }
    let(:query) { "SELECT COUNT(*) FROM users" }
    let(:db_response) { [{ "count" => 5 }] }
    let(:llm_response) { "Existem 5 usuários no banco de dados." }
    let(:expected_prompt_start) { "Keep in mind the language of the question is in" }

    before do
      allow(openai_client_double).to receive(:chat).and_return(
        {
          "choices" => [
            {
              "message" => {
                "role" => "assistant",
                "content" => llm_response
              }
            }
          ]
        }
      )
    end

    it "calls OpenAI client with the correct prompt and returns the LLM's answer" do
      expect(openai_client_double).to receive(:chat).with(
        parameters: hash_including(
          model: "gpt-3.5-turbo-test",
          messages: [hash_including(role: "user", content: a_string_including(expected_prompt_start))],
          temperature: 0.2,
          max_tokens: 250
        )
      ).and_return(
        {
          "choices" => [
            {
              "message" => {
                "role" => "assistant",
                "content" => llm_response
              }
            }
          ]
        }
      )
      expect(service.send(:answer_as_human, question, query, db_response)).to eq(llm_response)
    end

    it "raises ApiError on OpenAI API errors" do
      allow(openai_client_double).to receive(:chat).and_raise(OpenAI::Error.new("API error"))
      expect do
        service.send(:answer_as_human, question, query, db_response)
      end.to raise_error(AsktiveRecord::ApiError, "OpenAI API error: API error")
    end

    it "raises QueryGenerationError on other unexpected errors" do
      allow(openai_client_double).to receive(:chat).and_raise(StandardError.new("Unexpected error"))
      expect do
        service.send(:answer_as_human, question, query, db_response)
      end.to raise_error(AsktiveRecord::QueryGenerationError, "Failed to generate SQL query: Unexpected error")
    end

    it "returns nil if the LLM response is missing" do
      allow(openai_client_double).to receive(:chat).and_return({ "choices" => [{ "message" => { "content" => nil } }] })
      expect(service.send(:answer_as_human, question, query, db_response)).to be_nil
    end
  end
end
