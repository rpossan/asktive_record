# frozen_string_literal: true

module AsktiveRecord
  module Adapters
    # Base adapter class that defines the interface all LLM adapters must implement.
    # To create a custom adapter, inherit from this class and implement the required methods.
    #
    # @example Creating a custom adapter
    #   class MyAdapter < AsktiveRecord::Adapters::Base
    #     def chat(prompt, options = {})
    #       # Your LLM API call here
    #       # Must return a string response
    #     end
    #   end
    #
    #   AsktiveRecord.configure do |config|
    #     config.adapter = MyAdapter.new(api_key: ENV["MY_LLM_KEY"])
    #   end
    class Base
      attr_reader :api_key, :model_name

      def initialize(api_key:, model_name: nil)
        @api_key = api_key
        @model_name = model_name

        return if @api_key

        raise ConfigurationError,
              "LLM API key is required for adapter initialization."
      end

      # Send a prompt to the LLM and return the text response.
      #
      # @param prompt [String] the prompt to send
      # @param options [Hash] additional options (temperature, max_tokens, etc.)
      # @return [String, nil] the text response from the LLM
      def chat(prompt, options = {})
        raise NotImplementedError, "#{self.class.name} must implement #chat"
      end

      # Returns the default model name for this adapter.
      #
      # @return [String] the default model name
      def default_model_name
        raise NotImplementedError, "#{self.class.name} must implement #default_model_name"
      end

      # Returns the resolved model name (configured or default).
      #
      # @return [String]
      def resolved_model_name
        model_name || default_model_name
      end
    end
  end
end
