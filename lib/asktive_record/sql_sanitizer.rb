# frozen_string_literal: true

module AsktiveRecord
  # SqlSanitizer provides robust SQL sanitization to prevent injection attacks
  # from LLM-generated queries. It validates that queries are safe SELECT statements
  # and blocks dangerous patterns like DDL, DML, and injection techniques.
  class SqlSanitizer
    # SQL keywords that indicate dangerous operations
    DANGEROUS_KEYWORDS = %w[
      INSERT UPDATE DELETE DROP ALTER CREATE TRUNCATE
      REPLACE MERGE GRANT REVOKE EXEC EXECUTE
      CALL RENAME LOAD COPY INTO OUTFILE DUMPFILE
    ].freeze

    # Patterns that indicate SQL injection attempts
    INJECTION_PATTERNS = [
      /;\s*\S/i,                    # Semicolon followed by another statement
      /--\s/,                       # SQL line comment
      %r{/\*.*?\*/}m,               # SQL block comment
      /\bUNION\b.*\bSELECT\b/i, # UNION-based injection
      /\bINTO\s+OUTFILE\b/i,        # File write attempt
      /\bINTO\s+DUMPFILE\b/i,       # File dump attempt
      /\bLOAD_FILE\b/i,             # File read attempt
      /\bBENCHMARK\b/i,             # Time-based injection
      /\bSLEEP\b\s*\(/i,           # Time-based injection
      /\bIF\b\s*\(/i,              # Conditional injection (IF function)
      /\bCASE\s+WHEN\b.*\bTHEN\b.*\bWAITFOR\b/i, # Conditional time-based
      /\bWAITFOR\s+DELAY\b/i,      # MSSQL time-based injection
      /\bpg_sleep\b/i,             # PostgreSQL time-based injection
      /\bDBMS_LOCK\.SLEEP\b/i      # Oracle time-based injection
    ].freeze

    class << self
      # Sanitizes the given SQL string.
      # Raises AsktiveRecord::SanitizationError if the query is unsafe.
      #
      # @param sql [String] the SQL string to sanitize
      # @param allow_only_select [Boolean] whether to restrict to SELECT-only (default: true)
      # @return [String] the sanitized SQL string
      def sanitize!(sql, allow_only_select: true)
        raise SanitizationError, "SQL query cannot be nil or empty." if sql.nil? || sql.strip.empty?

        cleaned = clean_sql(sql)

        validate_select_only!(cleaned) if allow_only_select

        check_dangerous_keywords!(cleaned)
        check_injection_patterns!(cleaned)

        cleaned
      end

      private

      # Strips trailing semicolons and extra whitespace
      def clean_sql(sql)
        sql.strip.gsub(/;\s*\z/, "")
      end

      # Validates the query starts with SELECT
      def validate_select_only!(sql)
        return if sql.strip.match?(/\ASELECT\b/i)

        raise SanitizationError,
              "Query sanitization failed: Only SELECT statements are allowed. Got: #{sql.split.first}"
      end

      # Checks for dangerous DDL/DML keywords in the query
      def check_dangerous_keywords!(sql)
        # Remove string literals to avoid false positives on quoted content
        sql_without_strings = sql.gsub(/'[^']*'/, "''").gsub(/"[^"]*"/, '""')

        DANGEROUS_KEYWORDS.each do |keyword|
          next unless sql_without_strings.match?(/\b#{keyword}\b/i)

          raise SanitizationError,
                "Query sanitization failed: Dangerous SQL keyword '#{keyword}' detected."
        end
      end

      # Checks for common SQL injection patterns
      def check_injection_patterns!(sql)
        INJECTION_PATTERNS.each do |pattern|
          next unless sql.match?(pattern)

          raise SanitizationError,
                "Query sanitization failed: Potentially dangerous SQL pattern detected."
        end
      end
    end
  end
end
