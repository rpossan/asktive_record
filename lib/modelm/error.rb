# frozen_string_literal: true

module Modelm
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class ApiError < Error; end
  class QueryGenerationError < Error; end
  class QueryExecutionError < Error; end
  class SanitizationError < Error; end
end

