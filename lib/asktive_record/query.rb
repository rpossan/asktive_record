# frozen_string_literal: true

module AsktiveRecord
  # The Query class encapsulates a natural language question, its corresponding SQL,
  # and provides methods for sanitization, execution, and generating answers using LLMs.
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
      unless @sanitized_sql
        raise QueryExecutionError,
              "Cannot execute raw SQL. Call sanitize! first or work with sanitized_sql."
      end

      result = execute_query
      extract_count_if_present(result)
    rescue StandardError => e
      raise QueryExecutionError, "Failed to execute SQL query: #{e.message}"
    end

    def to_s
      @sanitized_sql || @raw_sql
    end

    private

    def execute_query
      if active_record_model?
        result = model_class.find_by_sql(@sanitized_sql)
        return result[0].count if result[0].respond_to?(:count)

        result
      else
        execute_raw_sql
      end
    end

    def active_record_model?
      model_class.respond_to?(:find_by_sql) && model_class.respond_to?(:table_name) && !model_class.table_name.to_s.empty?
    end

    def execute_raw_sql
      return unless defined?(ActiveRecord::Base)

      if ActiveRecord::Base.connection.respond_to?(:exec_query)
        # no-op here unless you're logging or observing
      end

      if select_query?
        ActiveRecord::Base.connection.select_all(@sanitized_sql)
      else
        ActiveRecord::Base.connection.execute(@sanitized_sql)
      end
    end

    def select_query?
      @sanitized_sql.strip.downcase.start_with?("select")
    end

    def extract_count_if_present(result)
      return result unless result.is_a?(Array) && result[0].is_a?(Hash) && result[0].key?("count")

      result[0]["count"]
    end
  end
end
