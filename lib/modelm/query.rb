# frozen_string_literal: true

module Modelm
  class Query
    attr_reader :raw_sql, :model_class
    attr_accessor :sanitized_sql

    def initialize(raw_sql, model_class)
      @raw_sql = raw_sql
      @model_class = model_class
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

    def execute
      # Ensure the query has been (at least potentially) sanitized
      raise QueryExecutionError, "Cannot execute raw SQL. Call sanitize! first or work with sanitized_sql." unless @sanitized_sql

      # In a Rails context, this would use ActiveRecord::Base.connection.execute or model_class.find_by_sql
      # puts "Executing SQL: #{@sanitized_sql}" # Optional: for debugging
      begin
        if model_class.respond_to?(:find_by_sql)
          model_class.find_by_sql(@sanitized_sql)
        else
          # This case should ideally not be hit if used with ActiveRecord models.
          # If it's intended for other ORMs or direct use, this path might need adjustment or clearer error.
          raise NoMethodError, "The model class #{model_class} does not respond to :find_by_sql. Modelm currently relies on this method for query execution."
        end
      rescue => e
        raise QueryExecutionError, "Failed to execute SQL query: #{e.message}"
      end
    end

    def to_s
      @sanitized_sql || @raw_sql
    end
  end
end

