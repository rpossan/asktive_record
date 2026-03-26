# frozen_string_literal: true

require "spec_helper"
require "asktive_record/schema_loader"
require "asktive_record/error"
require "fileutils"

# Test class to include the SchemaLoader module
class SchemaLoaderTestClass
  extend AsktiveRecord::SchemaLoader
end

RSpec.describe AsktiveRecord::SchemaLoader do
  let(:test_class) { SchemaLoaderTestClass }
  let(:schema_content) { "CREATE TABLE users (id INTEGER, name VARCHAR(255));" }

  before do
    AsktiveRecord.configure do |c|
      c.llm_api_key = "test_key"
      c.db_schema_path = "spec/fixtures/schema_loader_test.rb"
    end
    FileUtils.mkdir_p("spec/fixtures")
  end

  after do
    FileUtils.rm_rf("spec/fixtures")
    FileUtils.rm_f("db/structure.sql")
    AsktiveRecord.configuration = nil
  end

  describe "#load_schema_content" do
    context "when schema file exists" do
      before do
        File.write(AsktiveRecord.configuration.db_schema_path, schema_content)
      end

      it "reads and returns the schema content" do
        result = test_class.load_schema_content
        expect(result).to eq(schema_content)
      end
    end

    context "when schema file does not exist but structure.sql does" do
      before do
        FileUtils.mkdir_p("db")
        File.write("db/structure.sql", schema_content)
      end

      after do
        FileUtils.rm_rf("db")
      end

      it "falls back to structure.sql" do
        result = test_class.load_schema_content
        expect(result).to eq(schema_content)
      end
    end

    context "when no schema file exists" do
      it "raises ConfigurationError" do
        expect do
          test_class.load_schema_content
        end.to raise_error(AsktiveRecord::ConfigurationError, /Database schema file not found/)
      end
    end

    context "when schema file read raises SystemCallError" do
      before do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(AsktiveRecord.configuration.db_schema_path).and_return(true)
        allow(File).to receive(:read).with(AsktiveRecord.configuration.db_schema_path).and_raise(
          Errno::EACCES, "Permission denied"
        )
      end

      it "raises ConfigurationError with the original error message" do
        expect do
          test_class.load_schema_content
        end.to raise_error(AsktiveRecord::ConfigurationError, /Permission denied/)
      end
    end
  end

  describe "#ensure_schema_is_not_empty!" do
    it "does nothing for non-empty content" do
      expect { test_class.ensure_schema_is_not_empty!("some content") }.not_to raise_error
    end

    it "raises ConfigurationError for nil content" do
      expect do
        test_class.ensure_schema_is_not_empty!(nil)
      end.to raise_error(AsktiveRecord::ConfigurationError, /Schema content is empty/)
    end

    it "raises ConfigurationError for empty string" do
      expect do
        test_class.ensure_schema_is_not_empty!("")
      end.to raise_error(AsktiveRecord::ConfigurationError, /Schema content is empty/)
    end

    it "raises ConfigurationError for whitespace-only content" do
      expect do
        test_class.ensure_schema_is_not_empty!("  \n  ")
      end.to raise_error(AsktiveRecord::ConfigurationError, /Schema content is empty/)
    end
  end

  describe "#validate_llm_api_key!" do
    it "does nothing when API key is configured" do
      expect { test_class.validate_llm_api_key! }.not_to raise_error
    end

    it "raises ConfigurationError when API key is nil" do
      AsktiveRecord.configuration.llm_api_key = nil
      expect do
        test_class.validate_llm_api_key!
      end.to raise_error(AsktiveRecord::ConfigurationError, /LLM API key is not configured/)
    end

    it "raises ConfigurationError when configuration is nil" do
      AsktiveRecord.configuration = nil
      expect do
        test_class.validate_llm_api_key!
      end.to raise_error(AsktiveRecord::ConfigurationError, /LLM API key is not configured/)
    end
  end
end
