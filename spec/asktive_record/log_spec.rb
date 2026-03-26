# frozen_string_literal: true

require "spec_helper"
require "asktive_record/log"

RSpec.describe AsktiveRecord::Log do
  let(:mock_logger) { instance_double(Logger) }

  after do
    described_class.logger = nil # Reset to default
  end

  describe ".logger" do
    it "returns a logger instance" do
      expect(described_class.logger).to respond_to(:info)
      expect(described_class.logger).to respond_to(:debug)
      expect(described_class.logger).to respond_to(:warn)
      expect(described_class.logger).to respond_to(:error)
    end

    it "defaults to a standard Logger when Rails is not defined" do
      described_class.logger = nil
      hide_const("Rails") if defined?(Rails)
      expect(described_class.logger).to be_a(Logger)
    end
  end

  describe ".logger=" do
    it "allows setting a custom logger" do
      custom_logger = Logger.new(StringIO.new)
      described_class.logger = custom_logger
      expect(described_class.logger).to eq(custom_logger)
    end
  end

  describe ".info" do
    it "logs an info message with prefix" do
      described_class.logger = mock_logger
      expect(mock_logger).to receive(:info).with("[AsktiveRecord] Test message")
      described_class.info("Test message")
    end
  end

  describe ".debug" do
    it "logs a debug message with prefix" do
      described_class.logger = mock_logger
      expect(mock_logger).to receive(:debug).with("[AsktiveRecord] Debug info")
      described_class.debug("Debug info")
    end
  end

  describe ".warn" do
    it "logs a warn message with prefix" do
      described_class.logger = mock_logger
      expect(mock_logger).to receive(:warn).with("[AsktiveRecord] Warning!")
      described_class.warn("Warning!")
    end
  end

  describe ".error" do
    it "logs an error message with prefix" do
      described_class.logger = mock_logger
      expect(mock_logger).to receive(:error).with("[AsktiveRecord] Something failed")
      described_class.error("Something failed")
    end
  end
end
