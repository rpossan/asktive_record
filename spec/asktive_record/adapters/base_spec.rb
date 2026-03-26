# frozen_string_literal: true

require "./spec/spec_helper"
require "asktive_record/adapters/base"
require "asktive_record/error"

RSpec.describe AsktiveRecord::Adapters::Base do
  let(:api_key) { "test_api_key" }

  describe "#initialize" do
    it "stores the api_key" do
      adapter = described_class.new(api_key: api_key)
      expect(adapter.api_key).to eq(api_key)
    end

    it "stores the model_name if provided" do
      adapter = described_class.new(api_key: api_key, model_name: "custom-model")
      expect(adapter.model_name).to eq("custom-model")
    end

    it "defaults model_name to nil" do
      adapter = described_class.new(api_key: api_key)
      expect(adapter.model_name).to be_nil
    end

    it "raises ConfigurationError if API key is nil" do
      expect do
        described_class.new(api_key: nil)
      end.to raise_error(AsktiveRecord::ConfigurationError, /LLM API key is required/)
    end

    it "raises ConfigurationError if API key is blank-ish (nil)" do
      expect do
        described_class.new(api_key: nil)
      end.to raise_error(AsktiveRecord::ConfigurationError)
    end
  end

  describe "#chat" do
    it "raises NotImplementedError" do
      adapter = described_class.new(api_key: api_key)
      expect do
        adapter.chat("Hello")
      end.to raise_error(NotImplementedError, /must implement #chat/)
    end
  end

  describe "#default_model_name" do
    it "raises NotImplementedError" do
      adapter = described_class.new(api_key: api_key)
      expect do
        adapter.default_model_name
      end.to raise_error(NotImplementedError, /must implement #default_model_name/)
    end
  end

  describe "#resolved_model_name" do
    it "returns the configured model_name if present" do
      adapter = described_class.new(api_key: api_key, model_name: "custom-model")
      expect(adapter.resolved_model_name).to eq("custom-model")
    end

    it "falls back to default_model_name if model_name is nil" do
      adapter = described_class.new(api_key: api_key)
      allow(adapter).to receive(:default_model_name).and_return("default-model")
      expect(adapter.resolved_model_name).to eq("default-model")
    end
  end
end
