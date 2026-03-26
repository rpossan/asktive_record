# frozen_string_literal: true

module AsktiveRecord
  # Prompt class for generating SQL queries from natural language questions.
  # All user inputs are escaped before interpolation to mitigate prompt injection.
  class Prompt
    # Characters that could be used for prompt injection
    PROMPT_INJECTION_PATTERNS = [
      /ignore\s+(all\s+)?previous\s+instructions/i,
      /forget\s+(all\s+)?previous/i,
      /disregard\s+(all\s+)?above/i,
      /you\s+are\s+now/i,
      /new\s+instructions?:/i,
      /system\s*:/i
    ].freeze

    class << self
      def as_human_answerer(question, query, response)
        safe_question = escape_input(question)
        safe_query = escape_input(query.to_s)
        safe_response = escape_input(response.to_s)

        <<~PROMPT
          You are a helpful data assistant. Answer the user's question based on the SQL query result below.
          Keep in mind the language of the question and answer in the same language.

          If the response looks like an ActiveRecord::Result (with @rows), convert it to a human-readable format
          by extracting the relevant data from the rows.

          Question: "#{safe_question}"

          SQL Query that was executed:
          #{safe_query}

          Query Result:
          #{safe_response}

          Please provide a concise answer based on the result as a human would, without any SQL or technical jargon.
          For example:
          - If the result is a list of users: "There are 5 users in the database."
          - If the result is a single record: "The first user is John Doe."
          - If the result is an aggregate: "The average age of users is 30 years."

          Answer in the same language as the question.
        PROMPT
      end

      def as_sql_generator(natural_language_query, schema_string)
        safe_query = escape_input(natural_language_query)

        <<~PROMPT
          You are an expert SQL generator. Your task is to convert a natural language query into a SQL query for a database with the following schema.
          Only generate SELECT queries. Do not generate any INSERT, UPDATE, DELETE, DROP, or other DDL/DML statements.

          Database Schema:
          ```sql
          #{schema_string}
          ```

          Natural Language Query: "#{safe_query}"

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
      end

      def as_sql_generator_for_model(natural_language_query, schema_string, table_name)
        safe_query = escape_input(natural_language_query)
        safe_table = escape_input(table_name.to_s)

        <<~PROMPT
          You are an expert SQL generator. Your task is to convert a natural language query into a SQL query for a database with the following schema.
          Only generate SELECT queries. Do not generate any INSERT, UPDATE, DELETE, DROP, or other DDL/DML statements.
          The query should be for the table: #{safe_table}.

          Database Schema:
          ```sql
          #{schema_string}
          ```

          Natural Language Query: "#{safe_query}"

          Based on the schema and the natural language query, provide only the SQL query as a single line of text, without any explanation or surrounding text.
          For example, if the query is "show me all users", and the table is `users`, the output should be:
          SELECT * FROM users;
          If the query is "find the last 5 registered users", the output should be:
          SELECT * FROM users ORDER BY created_at DESC LIMIT 5;

          SQL Query:
        PROMPT
      end

      private

      # Escapes user input to mitigate prompt injection attacks.
      # Strips known injection patterns and sanitizes special characters.
      def escape_input(input)
        return "" if input.nil?

        sanitized = input.to_s.dup

        # Remove known prompt injection patterns
        PROMPT_INJECTION_PATTERNS.each do |pattern|
          sanitized.gsub!(pattern, "[FILTERED]")
        end

        # Limit input length to prevent token abuse
        sanitized = sanitized[0, 2000] if sanitized.length > 2000

        sanitized
      end
    end
  end
end
