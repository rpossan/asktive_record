# frozen_string_literal: true

require "logger"

module AsktiveRecord
  # Provides a configurable logging interface for AsktiveRecord.
  # Defaults to Rails.logger when available, or a standard Logger to $stdout.
  #
  # Usage:
  #   AsktiveRecord.logger.info("Something happened")
  #   AsktiveRecord.logger.debug("Debug info")
  module Log
    PREFIX = "[AsktiveRecord]"

    class << self
      def logger
        @logger ||= default_logger
      end

      attr_writer :logger

      def info(message)
        logger.info("#{PREFIX} #{message}")
      end

      def debug(message)
        logger.debug("#{PREFIX} #{message}")
      end

      def warn(message)
        logger.warn("#{PREFIX} #{message}")
      end

      def error(message)
        logger.error("#{PREFIX} #{message}")
      end

      private

      def default_logger
        if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
          Rails.logger
        else
          ::Logger.new($stdout, level: ::Logger::INFO)
        end
      end
    end
  end
end
