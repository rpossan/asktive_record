# frozen_string_literal: true

require "./spec/spec_helper"
require "asktive_record/llm_service"
require "asktive_record/configuration"
require "asktive_record/adapters/base"
require "asktive_record/error"

RSpec.describe AsktiveRecord::LlmService do
  let(:api_key) { "test_api_key" }
  let(:configuration) do
    config = AsktiveRecord::Configuration.new
    config.llm_api_key = api_key
    config.llm_model_name = "gpt-4o-mini-test"
    config
  end
  let(:adapter_double) { instance_double(AsktiveRecord::Adapters::Base) }
  let(:service) { AsktiveRecord::LlmService.new(configuration) }

  before do
    allow(configuration).to receive(:resolved_adapter).and_return(adapter_double)
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
                         /LLM API key is not configured/)
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

    it "generates SQL successfully for a valid service query" do
      allow(adapter_double).to receive(:chat).and_return("#{expected_sql};")
      sql = service.generate_sql_for_service(natural_language_query, schema_string, target_table)
      expect(sql).to eq(expected_sql)
    end

    it "constructs the correct prompt and passes it to the adapter" do
      expected_prompt = AsktiveRecord::Prompt.as_sql_generator(natural_language_query, schema_string)

      expect(adapter_double).to receive(:chat).with(
        expected_prompt,
        { temperature: 0.2, max_tokens: 250 }
      ).and_return("#{expected_sql};")

      service.generate_sql_for_service(natural_language_query, schema_string, target_table)
    end

    it "raises QueryGenerationError if LLM returns a non-SELECT query" do
      allow(adapter_double).to receive(:chat).and_return("DROP TABLE products;")
      expect do
        service.generate_sql_for_service(natural_language_query, schema_string, target_table)
      end.to raise_error(AsktiveRecord::QueryGenerationError, /LLM generated a non-SELECT query/)
    end

    it "raises QueryGenerationError if LLM returns no content" do
      allow(adapter_double).to receive(:chat).and_return("")
      expect do
        service.generate_sql_for_service(natural_language_query, schema_string, target_table)
      end.to raise_error(AsktiveRecord::QueryGenerationError, /LLM did not return a SQL query/)
    end

    it "raises QueryGenerationError if LLM returns nil" do
      allow(adapter_double).to receive(:chat).and_return(nil)
      expect do
        service.generate_sql_for_service(natural_language_query, schema_string, target_table)
      end.to raise_error(AsktiveRecord::QueryGenerationError, /LLM did not return a SQL query/)
    end

    it "raises ApiError on LLM adapter API errors" do
      allow(adapter_double).to receive(:chat).and_raise(AsktiveRecord::ApiError.new("OpenAI API error: API connection error"))
      expect do
        service.generate_sql_for_service(natural_language_query, schema_string, target_table)
      end.to raise_error(AsktiveRecord::ApiError, "OpenAI API error: API connection error")
    end

    it "raises QueryGenerationError on other unexpected errors during generation" do
      allow(adapter_double).to receive(:chat).and_raise(StandardError.new("Unexpected issue"))
      expect do
        service.generate_sql_for_service(natural_language_query, schema_string, target_table)
      end.to raise_error(AsktiveRecord::QueryGenerationError, "Failed to generate SQL query: Unexpected issue")
    end
  end

  describe "#generate_sql" do
    let(:natural_language_query) { "show me all users" }
    let(:schema_string) { "CREATE TABLE users (id INTEGER, name VARCHAR(255));" }
    let(:table_name) { "users" }
    let(:expected_sql) { "SELECT * FROM users" }

    it "generates SQL successfully for a valid query" do
      allow(adapter_double).to receive(:chat).and_return("#{expected_sql};")
      sql = service.generate_sql(natural_language_query, schema_string, table_name)
      expect(sql).to eq(expected_sql) # Semicolon should be cleaned
    end

    it "constructs the correct prompt" do
      expected_prompt = AsktiveRecord::Prompt.as_sql_generator_for_model(natural_language_query, schema_string,
                                                                        table_name)

      expect(adapter_double).to receive(:chat).with(
        expected_prompt,
        { temperature: 0.2, max_tokens: 250 }
      ).and_return("#{expected_sql};")

      service.generate_sql(natural_language_query, schema_string, table_name)
    end

    it "raises QueryGenerationError if LLM returns a non-SELECT query" do
      allow(adapter_double).to receive(:chat).and_return("DROP TABLE users;")
      expect do
        service.generate_sql(natural_language_query, schema_string, table_name)
      end.to raise_error(AsktiveRecord::QueryGenerationError, /LLM generated a non-SELECT query/)
    end

    it "raises QueryGenerationError if LLM returns no content" do
      allow(adapter_double).to receive(:chat).and_return("")
      expect do
        service.generate_sql(natural_language_query, schema_string, table_name)
      end.to raise_error(AsktiveRecord::QueryGenerationError, /LLM did not return a SQL query/)
    end

    it "raises ApiError on LLM adapter API errors" do
      allow(adapter_double).to receive(:chat).and_raise(AsktiveRecord::ApiError.new("OpenAI API error: API connection error"))
      expect do
        service.generate_sql(natural_language_query, schema_string, table_name)
      end.to raise_error(AsktiveRecord::ApiError, "OpenAI API error: API connection error")
    end

    it "raises QueryGenerationError on other unexpected errors during generation" do
      allow(adapter_double).to receive(:chat).and_raise(StandardError.new("Unexpected issue"))
      expect do
        service.generate_sql(natural_language_query, schema_string, table_name)
      end.to raise_error(AsktiveRecord::QueryGenerationError, "Failed to generate SQL query: Unexpected issue")
    end
  end

  describe "#upload_schema" do
    it "is a placeholder and returns true" do
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

    it "logs debug information via AsktiveRecord::Log" do
      expect(AsktiveRecord::Log).to receive(:info).with("Answering question: #{question}")
      expect(AsktiveRecord::Log).to receive(:debug).with("Generated SQL query: #{query}")
      expect(AsktiveRecord::Log).to receive(:debug).with("Response from database: #{db_response.inspect}")
      service.answer(question, query, db_response)
    end
  end

  describe "#answer_as_human" do
    let(:question) { "Quantos usuários existem?" }
    let(:query) { "SELECT COUNT(*) FROM users" }
    let(:db_response) { [{ "count" => 5 }] }
    let(:llm_response) { "Existem 5 usuários no banco de dados." }

    before do
      allow(adapter_double).to receive(:chat).and_return(llm_response)
    end

    it "calls the adapter with the correct prompt and returns the LLM's answer" do
      expected_prompt = AsktiveRecord::Prompt.as_human_answerer(question, query, db_response)

      expect(adapter_double).to receive(:chat).with(
        expected_prompt,
        { temperature: 0.2, max_tokens: 250 }
      ).and_return(llm_response)

      expect(service.send(:answer_as_human, question, query, db_response)).to eq(llm_response)
    end

    it "raises ApiError on LLM adapter API errors" do
      allow(adapter_double).to receive(:chat).and_raise(AsktiveRecord::ApiError.new("OpenAI API error: API error"))
      expect do
        service.send(:answer_as_human, question, query, db_response)
      end.to raise_error(AsktiveRecord::ApiError, "OpenAI API error: API error")
    end

    it "raises QueryGenerationError on other unexpected errors" do
      allow(adapter_double).to receive(:chat).and_raise(StandardError.new("Unexpected error"))
      expect do
        service.send(:answer_as_human, question, query, db_response)
      end.to raise_error(AsktiveRecord::QueryGenerationError, "Failed to generate SQL query: Unexpected error")
    end

    it "returns nil if the LLM response is missing" do
      allow(adapter_double).to receive(:chat).and_return(nil)
      expect(service.send(:answer_as_human, question, query, db_response)).to be_nil
    end
  end
end
