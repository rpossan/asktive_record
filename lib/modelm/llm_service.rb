# frozen_string_literal: true
require "openai"

module Modelm
  class LlmService
    attr_reader :configuration

    def initialize(configuration)
      @configuration = configuration
      unless @configuration&.llm_api_key
        raise ConfigurationError, "LLM API key is not configured. Please set it in config/initializers/modelm.rb or via environment variable."
      end
    end

    # Original method for model-specific queries
    def generate_sql(natural_language_query, schema_string, table_name)
      client = OpenAI::Client.new(access_token: configuration.llm_api_key)

      prompt = <<~PROMPT
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

      generate_and_validate_sql(client, prompt)
    end

    # New method for service-class-based queries that can target any table
    def generate_sql_for_service(natural_language_query, schema_string, target_table = "any")
      client = OpenAI::Client.new(access_token: configuration.llm_api_key)

      prompt = <<~PROMPT
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

      generate_and_validate_sql(client, prompt)
    end

    private

    def generate_and_validate_sql(client, prompt)
      begin
        response = client.chat(
          parameters: {
            model: configuration.llm_model_name || "gpt-3.5-turbo",
            messages: [{ role: "user", content: prompt }],
            temperature: 0.2, # Lower temperature for more deterministic SQL output
            max_tokens: 250 # Increased max tokens for more complex queries with JOINs
          }
        )
        
        raw_sql = response.dig("choices", 0, "message", "content")&.strip
        
        if raw_sql && !raw_sql.empty?
          # Basic validation: ensure it's a SELECT query as requested
          unless raw_sql.downcase.start_with?("select")
            raise QueryGenerationError, "LLM generated a non-SELECT query: #{raw_sql}"
          end
          # Remove trailing semicolon if present, as some DB adapters don't like it with find_by_sql
          raw_sql.chomp(";") 
        else
          raise QueryGenerationError, "LLM did not return a SQL query. Response: #{response.inspect}"
        end
      rescue OpenAI::Error => e
        raise ApiError, "OpenAI API error: #{e.message}"
      rescue => e
        raise QueryGenerationError, "Failed to generate SQL query: #{e.message}"
      end
    end

    # Placeholder for schema upload/management with the LLM if needed for more advanced scenarios
    # For instance, if using OpenAI Assistants API or fine-tuning.
    # For now, the schema is passed with each query.
    def upload_schema(schema_string)
      # This could be used to upload schema to a vector store or a fine-tuning dataset in the future.
      puts "Schema upload functionality is a placeholder for now."
      true
    end
  end
end
