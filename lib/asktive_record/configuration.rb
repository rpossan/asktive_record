# frozen_string_literal: true

module AsktiveRecord
  # Configuration class for AsktiveRecord
  # This class holds the configuration settings for the LLM provider, API key, model name,
  # database schema path, logging preferences, and adapter settings.
  class Configuration
    attr_accessor :llm_provider, :llm_api_key, :llm_model_name, :db_schema_path,
                  :skip_dump_schema, :logger, :read_only, :adapter,
                  :temperature, :max_tokens, :cache_enabled

    def initialize
      @llm_provider = :openai # Default LLM provider
      @llm_api_key = nil
      @llm_model_name = "gpt-4o-mini" # Default model for OpenAI (gpt-3.5-turbo is deprecated)
      @db_schema_path = "db/schema.rb" # Default path for Rails schema file
      @skip_dump_schema = false # Default is to not skip schema dump
      @logger = nil # Will use AsktiveRecord::Log default if nil
      @read_only = true # Default to read-only mode (SELECT only)
      @adapter = nil # Will be built from llm_provider if nil
      @temperature = 0.2 # Default temperature for LLM
      @max_tokens = 250 # Default max tokens for LLM response
      @cache_enabled = false # Disabled by default
    end

    # Builds and returns the appropriate adapter based on configuration.
    # If a custom adapter is set, returns it directly.
    # Otherwise, builds one from llm_provider setting.
    #
    # @return [AsktiveRecord::Adapters::Base] the configured adapter
    def resolved_adapter
      return @adapter if @adapter

      build_adapter_from_provider
    end

    private

    def build_adapter_from_provider
      case llm_provider
      when :openai
        require "asktive_record/adapters/openai"
        Adapters::OpenAI.new(api_key: llm_api_key, model_name: llm_model_name)
      else
        raise ConfigurationError,
              "Unsupported LLM provider: #{llm_provider}. " \
              "Supported providers: :openai. Or set a custom adapter via config.adapter."
      end
    end
  end
end
