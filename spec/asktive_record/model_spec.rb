# frozen_string_literal: true

require "spec_helper"
require "asktive_record"
require "asktive_record/model"
require "asktive_record/query"
require "asktive_record/configuration"
require "asktive_record/llm_service"
require "asktive_record/error"
require "fileutils" # Added FileUtils

# Mock a Rails-like model for testing purposes
class MockUserRecord
  extend AsktiveRecord::Model::ClassMethods # Extend with the module we want to test

  def self.table_name
    "mock_user_records"
  end

  # Include the AsktiveRecord module itself to simulate `include AsktiveRecord` in ApplicationRecord
  # and then `asktive_record` being called in the specific model.
  def self.asktive_record_setup
    AsktiveRecord.included(self) # Simulate the inclusion part
    asktive_record # Call the class method added by AsktiveRecord.included
  end
end

RSpec.describe AsktiveRecord::Model::ClassMethods do
  let(:mock_model) { MockUserRecord }
  let(:config) { AsktiveRecord.configuration } # Use the globally configured instance
  let(:llm_service_double) { instance_double(AsktiveRecord::LlmService) }
  # Added created_at for sorting tests
  let(:schema_content) do
    "CREATE TABLE mock_user_records (id INT, email VARCHAR(255), created_at DATETIME);"
  end
  let(:natural_query) { "find all users" }
  let(:generated_sql) { "SELECT * FROM mock_user_records" }

  before do
    # Setup AsktiveRecord configuration for each test
    AsktiveRecord.configure do |c|
      c.llm_api_key = "fake_api_key"
      c.db_schema_path = "spec/fixtures/schema.rb" # Use a fixture for schema
    end
    # Create a dummy schema file for tests
    FileUtils.mkdir_p("spec/fixtures")
    File.write(AsktiveRecord.configuration.db_schema_path, schema_content) # Use AsktiveRecord.configuration here

    allow(AsktiveRecord::LlmService).to receive(:new).with(AsktiveRecord.configuration).and_return(llm_service_double)
    # Allow both generate_sql and generate_sql_for_service to be called
    allow(llm_service_double).to receive(:generate_sql)
      .with(natural_query, schema_content, mock_model.table_name)
      .and_return(generated_sql)
    allow(llm_service_double).to receive(:generate_sql_for_service)
      .with(any_args)
      .and_return(generated_sql)

    # Call the setup that mimics how a Rails model would use AsktiveRecord
    mock_model.asktive_record_setup
  end

  after do
    # Clean up dummy schema file
    FileUtils.rm_rf("spec/fixtures")
    # Reset configuration to avoid interference between tests
    AsktiveRecord.configuration = nil
  end

  describe ".asktive_record" do
    it "sets up AsktiveRecord correctly on the class" do
      expect(AsktiveRecord.configuration).not_to be_nil
      expect(AsktiveRecord.configuration.llm_api_key).to eq("fake_api_key")
    end

    context "when AsktiveRecord is not configured" do
      it "raises a ConfigurationError" do
        AsktiveRecord.configuration = nil # Simulate unconfigured state
        class UnconfiguredMockUserRecordForAsktiveRecordTest; extend AsktiveRecord::Model::ClassMethods; end
        expect do
          UnconfiguredMockUserRecordForAsktiveRecordTest.asktive_record
        end.to raise_error(AsktiveRecord::ConfigurationError,
                           /AsktiveRecord is not configured/)
      end
    end
  end

  describe ".ask" do
    it "returns a AsktiveRecord::Query object" do
      query_object = mock_model.ask(natural_query)
      expect(query_object).to be_a(AsktiveRecord::Query)
      expect(query_object.raw_sql).to eq(generated_sql)
      expect(query_object.model_class).to eq(mock_model)
    end

    it "uses LlmService to generate SQL" do
      # Use allow instead of expect to be more flexible with the implementation
      allow(llm_service_double).to receive(:generate_sql)
        .with(natural_query, schema_content, mock_model.table_name)
        .and_return(generated_sql)
      mock_model.ask(natural_query)
    end

    context "when API key is not configured" do
      before do
        AsktiveRecord.configuration.llm_api_key = nil
      end
      it "raises ConfigurationError" do
        expect do
          mock_model.ask(natural_query)
        end.to raise_error(AsktiveRecord::ConfigurationError, "LLM API key is not configured for AsktiveRecord.")
      end
    end

    context "when schema file is not found" do
      before do
        FileUtils.rm_f(AsktiveRecord.configuration.db_schema_path) # Remove the schema file
        # Ensure Rails is not defined for this specific test path to avoid system call attempt
        hide_const("Rails") if defined?(Rails)
      end
      it "raises ConfigurationError if not in Rails and schema missing" do
        expect do
          mock_model.ask(natural_query)
        end.to raise_error(AsktiveRecord::ConfigurationError,
                           %r{Database schema file not found at spec/fixtures/schema.rb. AsktiveRecord needs schema context})
      end
    end

    context "when schema file is found but empty" do
      before do
        File.write(AsktiveRecord.configuration.db_schema_path, "  \n  ") # Write empty content
      end
      it "raises ConfigurationError" do
        expect do
          mock_model.ask(natural_query)
        end.to raise_error(AsktiveRecord::ConfigurationError,
                           "Schema content is empty. Cannot proceed without database schema context.")
      end
    end

    context "when in Rails environment and schema file is missing initially" do
      let(:rails_schema_path) { "db/schema.rb" }
      before do
        # Simulate being in a Rails environment
        stub_const("Rails", Class.new) unless defined?(Rails)
        allow(mock_model).to receive(:system).and_return(true) # Stub system calls like `bin/rails db:schema:dump` to succeed

        AsktiveRecord.configuration.db_schema_path = rails_schema_path
        FileUtils.mkdir_p("db") # Ensure dir exists
        FileUtils.rm_f(rails_schema_path)
        FileUtils.rm_f("db/structure.sql")
      end

      after do
        FileUtils.rm_rf("db")
      end

      it "attempts to dump schema and reads it if successful" do
        expect(mock_model).to receive(:system).with("bin/rails db:schema:dump").ordered.and_return(true)
        # Simulate schema dump creating the file
        allow(File).to receive(:exist?).with(rails_schema_path).and_return(false, true)
        allow(File).to receive(:read).with(rails_schema_path).and_return(schema_content)

        expect(llm_service_double).to receive(:generate_sql).with(natural_query, schema_content,
                                                                  mock_model.table_name).and_return(generated_sql)
        mock_model.ask(natural_query)
      end

      it "attempts to dump schema and reads structure.sql if schema.rb fails but structure.sql exists" do
        alt_schema_path = "db/structure.sql"
        expect(mock_model).to receive(:system).with("bin/rails db:schema:dump").ordered.and_return(true)
        allow(File).to receive(:exist?).with(rails_schema_path).and_return(false, false)
        allow(File).to receive(:exist?).with(alt_schema_path).and_return(true)
        allow(File).to receive(:read).with(alt_schema_path).and_return(schema_content)

        expect(llm_service_double).to receive(:generate_sql).with(natural_query, schema_content,
                                                                  mock_model.table_name).and_return(generated_sql)
        mock_model.ask(natural_query)
      end

      it "raises ConfigurationError if schema dump fails and no schema file is found" do
        expect(mock_model).to receive(:system).with("bin/rails db:schema:dump").ordered.and_return(true)
        allow(File).to receive(:exist?).with(rails_schema_path).and_return(false, false)
        allow(File).to receive(:exist?).with("db/structure.sql").and_return(false)

        expect do
          mock_model.ask(natural_query)
        end.to raise_error(AsktiveRecord::ConfigurationError,
                           %r{Database schema file not found at db/schema.rb or db/structure.sql even after attempting to dump})
      end
    end
  end
end

# Test the main AsktiveRecord module itself
RSpec.describe AsktiveRecord do
  before do
    AsktiveRecord.configuration = nil
  end

  describe ".configure" do
    it "yields a Configuration object" do
      expect { |b| AsktiveRecord.configure(&b) }.to yield_with_args(be_a(AsktiveRecord::Configuration))
    end

    it "assigns the configured object to AsktiveRecord.configuration" do
      AsktiveRecord.configure do |config|
        config.llm_api_key = "configured_key"
      end
      expect(AsktiveRecord.configuration).to be_a(AsktiveRecord::Configuration)
      expect(AsktiveRecord.configuration.llm_api_key).to eq("configured_key")
    end

    it "uses existing configuration if called multiple times" do
      AsktiveRecord.configure { |c| c.llm_api_key = "first_key" }
      first_config_object_id = AsktiveRecord.configuration.object_id
      AsktiveRecord.configure { |c| c.llm_model_name = "new_model" }
      expect(AsktiveRecord.configuration.object_id).to eq(first_config_object_id)
      expect(AsktiveRecord.configuration.llm_api_key).to eq("first_key")
      expect(AsktiveRecord.configuration.llm_model_name).to eq("new_model")
    end
  end

  describe ".included" do
    let(:base_class) { Class.new }
    it "extends the base class with Model::ClassMethods" do
      expect(base_class).not_to respond_to(:ask) # Check before inclusion
      AsktiveRecord.included(base_class)
      expect(base_class).to respond_to(:ask)
      expect(base_class).to respond_to(:asktive_record)
    end
  end
end
