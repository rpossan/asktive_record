# frozen_string_literal: true

require "spec_helper"
require "asktive_record/configuration"
require "asktive_record/adapters/base"
require "asktive_record/error"

RSpec.describe AsktiveRecord::Configuration do
  describe "#initialize" do
    it "initializes with default values" do
      config = AsktiveRecord::Configuration.new
      expect(config.llm_provider).to eq(:openai)
      expect(config.llm_api_key).to be_nil
      expect(config.llm_model_name).to eq("gpt-4o-mini")
      expect(config.db_schema_path).to eq("db/schema.rb")
      expect(config.skip_dump_schema).to eq(false)
      expect(config.read_only).to eq(true)
      expect(config.logger).to be_nil
      expect(config.adapter).to be_nil
      expect(config.temperature).to eq(0.2)
      expect(config.max_tokens).to eq(250)
      expect(config.cache_enabled).to eq(false)
    end
  end

  describe "attribute accessors" do
    it "allows setting and getting attributes" do
      config = AsktiveRecord::Configuration.new
      config.llm_provider = :another_llm
      config.llm_api_key = "test_key"
      config.llm_model_name = "test_model"
      config.db_schema_path = "custom/schema.sql"
      config.skip_dump_schema = true
      config.read_only = false
      config.temperature = 0.8
      config.max_tokens = 500
      config.cache_enabled = true

      expect(config.llm_provider).to eq(:another_llm)
      expect(config.llm_api_key).to eq("test_key")
      expect(config.llm_model_name).to eq("test_model")
      expect(config.db_schema_path).to eq("custom/schema.sql")
      expect(config.skip_dump_schema).to eq(true)
      expect(config.read_only).to eq(false)
      expect(config.temperature).to eq(0.8)
      expect(config.max_tokens).to eq(500)
      expect(config.cache_enabled).to eq(true)
    end
  end

  describe "#resolved_adapter" do
    it "returns a custom adapter when one is set" do
      config = AsktiveRecord::Configuration.new
      custom_adapter = instance_double(AsktiveRecord::Adapters::Base)
      config.adapter = custom_adapter

      expect(config.resolved_adapter).to eq(custom_adapter)
    end

    it "builds an OpenAI adapter when llm_provider is :openai and no custom adapter is set" do
      config = AsktiveRecord::Configuration.new
      config.llm_api_key = "test_key"
      config.llm_model_name = "gpt-4o"

      adapter = config.resolved_adapter
      expect(adapter).to be_a(AsktiveRecord::Adapters::OpenAI)
      expect(adapter.api_key).to eq("test_key")
      expect(adapter.model_name).to eq("gpt-4o")
    end

    it "raises ConfigurationError for unsupported providers" do
      config = AsktiveRecord::Configuration.new
      config.llm_provider = :anthropic
      config.llm_api_key = "test_key"

      expect do
        config.resolved_adapter
      end.to raise_error(AsktiveRecord::ConfigurationError, /Unsupported LLM provider: anthropic/)
    end
  end
end
