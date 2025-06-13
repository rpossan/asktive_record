# frozen_string_literal: true

require "debug"
module AsktiveRecord
  class Query
    attr_reader :raw_sql, :model_class, :natural_question
    attr_accessor :sanitized_sql

    def initialize(natural_question, raw_sql, model_class)
      @raw_sql = raw_sql
      @model_class = model_class
      @natural_question = natural_question
      @sanitized_sql = raw_sql # Initially, sanitized SQL is the same as raw SQL
    end

    # Placeholder for sanitization logic
    # In a real scenario, this would involve more sophisticated checks,
    # potentially allowing only SELECT statements or using a whitelist of allowed SQL patterns.
    def sanitize!(allow_only_select: true)
      if allow_only_select && !@sanitized_sql.strip.downcase.start_with?("select")
        raise SanitizationError, "Query sanitization failed: Only SELECT statements are allowed by default."
      end

      # Add more sanitization rules here as needed
      self # Return self for chaining
    end

    def answer
      response = execute
      llm = AsktiveRecord::LlmService.new(AsktiveRecord.configuration)
      response = response.inspect if response.respond_to?(:inspect)
      llm.answer(@natural_question, @sanitized_sql, response)
    end

    def execute
      # Ensure the query has been (at least potentially) sanitized
      unless @sanitized_sql
        raise QueryExecutionError,
              "Cannot execute raw SQL. Call sanitize! first or work with sanitized_sql."
      end

      begin
        if model_class.respond_to?(:find_by_sql) && !model_class.table_name.nil?
          # Execute using the model-specific method (for ActiveRecord models)
          result = model_class.find_by_sql(@sanitized_sql)
          result = result[0].count if result[0].respond_to?(:count)
          return result
        elsif defined?(ActiveRecord::Base)
          # Execute using the general ActiveRecord connection (for service classes)
          # Use select_all for SELECT queries, which returns an array of hashes
          # For other query types (if sanitization allows), execute might be needed
          result = if @sanitized_sql.strip.downcase.start_with?("select")
                     if ActiveRecord::Base.connection.respond_to?(:exec_query)
                       ActiveRecord::Base.connection.exec_query(@sanitized_sql)
                     end
                     ActiveRecord::Base.connection.select_all(@sanitized_sql)
                   else
                     # If sanitization allows non-SELECT, use select_all
                     # Note: This path requires careful sanitization to avoid security risks
                     if ActiveRecord::Base.connection.respond_to?(:exec_query)
                       ActiveRecord::Base.connection.exec_query(@sanitized_sql)
                     end
                     ActiveRecord::Base.connection.execute(@sanitized_sql)
                   end
        end

        # Return the result of the query execution

        result = result[0]["count"] if result && result.is_a?(Array) && result[0].key?("count")
        result
      rescue StandardError => e
        # Catch potential ActiveRecord::StatementInvalid or other DB errors
        raise QueryExecutionError, "Failed to execute SQL query: #{e.message}"
      end
    end

    def to_s
      @sanitized_sql || @raw_sql
    end
  end
end
