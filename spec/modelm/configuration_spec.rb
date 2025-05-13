# frozen_string_literal: true

require "spec_helper"
require "modelm/configuration"

RSpec.describe Modelm::Configuration do
  describe "#initialize" do
    it "initializes with default values" do
      config = Modelm::Configuration.new
      expect(config.llm_provider).to eq(:openai)
      expect(config.llm_api_key).to be_nil
      expect(config.llm_model_name).to eq("gpt-3.5-turbo")
      expect(config.db_schema_path).to eq("db/schema.rb")
    end
  end

  describe "attribute accessors" do
    it "allows setting and getting attributes" do
      config = Modelm::Configuration.new
      config.llm_provider = :another_llm
      config.llm_api_key = "test_key"
      config.llm_model_name = "test_model"
      config.db_schema_path = "custom/schema.sql"

      expect(config.llm_provider).to eq(:another_llm)
      expect(config.llm_api_key).to eq("test_key")
      expect(config.llm_model_name).to eq("test_model")
      expect(config.db_schema_path).to eq("custom/schema.sql")
    end
  end
end

