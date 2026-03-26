# frozen_string_literal: true

require "asktive_record/sql_sanitizer"
require "asktive_record/log"

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

      AsktiveRecord::Log.info("Received question: \"#{natural_question}\"")
      AsktiveRecord::Log.info("Generated SQL: #{raw_sql}")
    end

    # Sanitizes the SQL using the SqlSanitizer.
    # Raises AsktiveRecord::SanitizationError if the query is unsafe.
    #
    # @param allow_only_select [Boolean] restrict to SELECT-only (default: true)
    # @return [self] for chaining
    def sanitize!(allow_only_select: true)
      @sanitized_sql = SqlSanitizer.sanitize!(@sanitized_sql, allow_only_select: allow_only_select)
      AsktiveRecord::Log.info("Sanitized SQL: #{@sanitized_sql}")
      self # Return self for chaining
    end

    def answer
      response = execute
      llm = AsktiveRecord::LlmService.new(AsktiveRecord.configuration)
      response_text = response.respond_to?(:inspect) ? response.inspect : response.to_s
      llm.answer(@natural_question, @sanitized_sql, response_text)
    end

    def execute
      unless @sanitized_sql
        raise QueryExecutionError,
              "Cannot execute raw SQL. Call sanitize! first or work with sanitized_sql."
      end

      # Auto-sanitize before execution if not already done
      validate_before_execution!

      result = execute_query
      AsktiveRecord::Log.info("Query executed successfully.")
      AsktiveRecord::Log.debug("Query results: #{result.inspect}")
      result
    rescue QueryExecutionError
      raise
    rescue StandardError => e
      raise QueryExecutionError, "Failed to execute SQL query: #{e.message}"
    end

    def to_s
      @sanitized_sql || @raw_sql
    end

    private

    def validate_before_execution!
      # Always validate the SQL is safe before execution
      SqlSanitizer.sanitize!(@sanitized_sql, allow_only_select: read_only_mode?)
    end

    def read_only_mode?
      AsktiveRecord.configuration&.read_only != false
    end

    def execute_query
      if active_record_model?
        AsktiveRecord::Log.info("Executing SQL via #{model_class.name}.find_by_sql")
        model_class.find_by_sql(@sanitized_sql)
      else
        execute_raw_sql
      end
    end

    def active_record_model?
      model_class.respond_to?(:find_by_sql) && model_class.respond_to?(:table_name) && model_class.table_name.present?
    end

    def execute_raw_sql
      return unless defined?(ActiveRecord::Base)

      AsktiveRecord::Log.info("Executing SQL via ActiveRecord::Base.connection")

      if select_query?
        ActiveRecord::Base.connection.select_all(@sanitized_sql)
      else
        ActiveRecord::Base.connection.execute(@sanitized_sql)
      end
    end

    def select_query?
      @sanitized_sql.strip.match?(/\ASELECT\b/i)
    end
  end
end
