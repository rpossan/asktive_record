# frozen_string_literal: true

module AsktiveRecord
  # Prompt class for generating SQL queries from natural language questions
  class Prompt
    def self.as_human_answerer(question, query, response)
      <<~PROMPT
        Keep in mind the language of the question is in "#{question}".
        If thre responses seems like an ActiveRerecord::Result because probably it was running as inspec
        to be passed here, please convert it to a human-readable format. For example, get the @rows in the string
        and convert it to a human-readable format.
        Based on the provided schema, I ask about the following question:
        "#{question}" and you give me the following SQL generated:
        #{query}. So I executed the query and got the following result in my database:
        #{response}.
        Now I need you to answer the question based on what I asked you and the result I got.
        Please provide a concise answer based on the result as a human would, without any SQL or technical jargon.
        E.g. if the result is a list of users, you might say "There are 5 users in the database." or "The first user is John Doe." or "The average age of users is 30 years." depending on the context of the question.
        Answer in the same language as the question was asked in "#{question}"
      PROMPT
    end

    def self.as_sql_generator(natural_language_query, schema_string)
      <<~PROMPT
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
    end

    def self.as_sql_generator_for_model(natural_language_query, schema_string, table_name)
      <<~PROMPT
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
    end
  end
end
