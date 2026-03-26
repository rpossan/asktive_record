# frozen_string_literal: true

require "spec_helper"
require "asktive_record/configuration"

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

      expect(config.llm_provider).to eq(:another_llm)
      expect(config.llm_api_key).to eq("test_key")
      expect(config.llm_model_name).to eq("test_model")
      expect(config.db_schema_path).to eq("custom/schema.sql")
      expect(config.skip_dump_schema).to eq(true)
      expect(config.read_only).to eq(false)
    end
  end
end
