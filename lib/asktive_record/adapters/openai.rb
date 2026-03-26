# frozen_string_literal: true

require "openai"
require "asktive_record/adapters/base"

module AsktiveRecord
  module Adapters
    # OpenAI adapter for AsktiveRecord. Wraps the ruby-openai gem to provide
    # LLM communication capabilities.
    #
    # @example
    #   adapter = AsktiveRecord::Adapters::OpenAI.new(
    #     api_key: ENV["OPENAI_API_KEY"],
    #     model_name: "gpt-4o"
    #   )
    #   response = adapter.chat("Generate a SQL query...")
    class OpenAI < Base
      DEFAULT_MODEL = "gpt-4o-mini"
      DEFAULT_TEMPERATURE = 0.2
      DEFAULT_MAX_TOKENS = 250

      def initialize(api_key:, model_name: nil)
        super
        @client = nil
      end

      # Send a prompt to OpenAI and return the text response.
      #
      # @param prompt [String] the prompt to send
      # @param options [Hash] additional options
      # @option options [Float] :temperature (0.2) the temperature for response generation
      # @option options [Integer] :max_tokens (250) the maximum tokens in the response
      # @return [String, nil] the text response from the LLM
      def chat(prompt, options = {})
        response = client.chat(
          parameters: {
            model: resolved_model_name,
            messages: [{ role: "user", content: prompt }],
            temperature: options.fetch(:temperature, DEFAULT_TEMPERATURE),
            max_tokens: options.fetch(:max_tokens, DEFAULT_MAX_TOKENS)
          }
        )
        response.dig("choices", 0, "message", "content")&.strip
      rescue ::OpenAI::Error => e
        raise ApiError, "OpenAI API error: #{e.message}"
      end

      # Returns the default model name for OpenAI.
      #
      # @return [String]
      def default_model_name
        DEFAULT_MODEL
      end

      private

      def client
        @client ||= ::OpenAI::Client.new(access_token: api_key)
      end
    end
  end
end
