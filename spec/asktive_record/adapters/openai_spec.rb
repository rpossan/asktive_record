# frozen_string_literal: true

require "./spec/spec_helper"
require "asktive_record/adapters/openai"
require "asktive_record/error"

RSpec.describe AsktiveRecord::Adapters::OpenAI do
  let(:api_key) { "test_openai_key" }
  let(:adapter) { described_class.new(api_key: api_key) }
  let(:openai_client_double) { instance_double(OpenAI::Client) }

  before do
    allow(OpenAI::Client).to receive(:new).with(access_token: api_key).and_return(openai_client_double)
  end

  describe "#initialize" do
    it "inherits from Adapters::Base" do
      expect(adapter).to be_a(AsktiveRecord::Adapters::Base)
    end

    it "stores the api_key" do
      expect(adapter.api_key).to eq(api_key)
    end

    it "accepts a custom model_name" do
      custom_adapter = described_class.new(api_key: api_key, model_name: "gpt-4o")
      expect(custom_adapter.model_name).to eq("gpt-4o")
    end
  end

  describe "#default_model_name" do
    it "returns gpt-4o-mini" do
      expect(adapter.default_model_name).to eq("gpt-4o-mini")
    end
  end

  describe "#resolved_model_name" do
    it "returns the default model when no custom model is set" do
      expect(adapter.resolved_model_name).to eq("gpt-4o-mini")
    end

    it "returns the custom model when set" do
      custom_adapter = described_class.new(api_key: api_key, model_name: "gpt-4o")
      expect(custom_adapter.resolved_model_name).to eq("gpt-4o")
    end
  end

  describe "#chat" do
    let(:prompt) { "Generate a SELECT query" }
    let(:chat_response) do
      {
        "choices" => [
          {
            "message" => {
              "role" => "assistant",
              "content" => "SELECT * FROM users"
            }
          }
        ]
      }
    end

    it "calls the OpenAI client with correct parameters" do
      expect(openai_client_double).to receive(:chat).with(
        parameters: {
          model: "gpt-4o-mini",
          messages: [{ role: "user", content: prompt }],
          temperature: 0.2,
          max_tokens: 250
        }
      ).and_return(chat_response)

      result = adapter.chat(prompt)
      expect(result).to eq("SELECT * FROM users")
    end

    it "uses custom temperature and max_tokens from options" do
      expect(openai_client_double).to receive(:chat).with(
        parameters: {
          model: "gpt-4o-mini",
          messages: [{ role: "user", content: prompt }],
          temperature: 0.8,
          max_tokens: 500
        }
      ).and_return(chat_response)

      adapter.chat(prompt, temperature: 0.8, max_tokens: 500)
    end

    it "uses the configured model name" do
      custom_adapter = described_class.new(api_key: api_key, model_name: "gpt-4o")

      expect(openai_client_double).to receive(:chat).with(
        parameters: hash_including(model: "gpt-4o")
      ).and_return(chat_response)

      custom_adapter.chat(prompt)
    end

    it "strips the response content" do
      response_with_whitespace = {
        "choices" => [{ "message" => { "content" => "  SELECT * FROM users  " } }]
      }
      allow(openai_client_double).to receive(:chat).and_return(response_with_whitespace)

      expect(adapter.chat(prompt)).to eq("SELECT * FROM users")
    end

    it "returns nil if response content is nil" do
      nil_response = {
        "choices" => [{ "message" => { "content" => nil } }]
      }
      allow(openai_client_double).to receive(:chat).and_return(nil_response)

      expect(adapter.chat(prompt)).to be_nil
    end

    it "raises ApiError on OpenAI::Error" do
      allow(openai_client_double).to receive(:chat).and_raise(OpenAI::Error.new("rate limit exceeded"))

      expect do
        adapter.chat(prompt)
      end.to raise_error(AsktiveRecord::ApiError, "OpenAI API error: rate limit exceeded")
    end
  end
end
