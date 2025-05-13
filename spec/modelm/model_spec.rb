# frozen_string_literal: true

require "spec_helper"
require "modelm"
require "modelm/model"
require "modelm/query"
require "modelm/configuration"
require "modelm/llm_service"
require "modelm/error"
require "fileutils" # Added FileUtils

# Mock a Rails-like model for testing purposes
class MockUserRecord
  extend Modelm::Model::ClassMethods # Extend with the module we want to test

  def self.table_name
    "mock_user_records"
  end

  # Include the Modelm module itself to simulate `include Modelm` in ApplicationRecord
  # and then `modelm` being called in the specific model.
  def self.modelm_setup
    Modelm.included(self) # Simulate the inclusion part
    modelm # Call the class method added by Modelm.included
  end
end

RSpec.describe Modelm::Model::ClassMethods do
  let(:mock_model) { MockUserRecord }
  let(:config) { Modelm.configuration } # Use the globally configured instance
  let(:llm_service_double) { instance_double(Modelm::LlmService) }
  let(:schema_content) { "CREATE TABLE mock_user_records (id INT, email VARCHAR(255), created_at DATETIME);" } # Added created_at for sorting tests
  let(:natural_query) { "find all users" }
  let(:generated_sql) { "SELECT * FROM mock_user_records" }

  before do
    # Setup Modelm configuration for each test
    Modelm.configure do |c|
      c.llm_api_key = "fake_api_key"
      c.db_schema_path = "spec/fixtures/schema.rb" # Use a fixture for schema
    end
    # Create a dummy schema file for tests
    FileUtils.mkdir_p("spec/fixtures")
    File.write(Modelm.configuration.db_schema_path, schema_content) # Use Modelm.configuration here

    allow(Modelm::LlmService).to receive(:new).with(Modelm.configuration).and_return(llm_service_double)
    allow(llm_service_double).to receive(:generate_sql)
      .with(natural_query, schema_content, mock_model.table_name)
      .and_return(generated_sql)
    
    # Call the setup that mimics how a Rails model would use Modelm
    mock_model.modelm_setup
  end

  after do
    # Clean up dummy schema file
    FileUtils.rm_rf("spec/fixtures")
    # Reset configuration to avoid interference between tests
    Modelm.configuration = nil 
  end

  describe ".modelm" do
    it "sets up Modelm correctly on the class" do
      expect(Modelm.configuration).not_to be_nil
      expect(Modelm.configuration.llm_api_key).to eq("fake_api_key")
    end

    context "when Modelm is not configured" do
      it "raises a ConfigurationError" do
        Modelm.configuration = nil # Simulate unconfigured state
        class UnconfiguredMockUserRecordForModelmTest; extend Modelm::Model::ClassMethods; end
        expect { UnconfiguredMockUserRecordForModelmTest.modelm }.to raise_error(Modelm::ConfigurationError, /Modelm is not configured/)
      end
    end
  end

  describe ".ask" do
    it "returns a Modelm::Query object" do
      query_object = mock_model.ask(natural_query)
      expect(query_object).to be_a(Modelm::Query)
      expect(query_object.raw_sql).to eq(generated_sql)
      expect(query_object.model_class).to eq(mock_model)
    end

    it "uses LlmService to generate SQL" do
      expect(llm_service_double).to receive(:generate_sql)
        .with(natural_query, schema_content, mock_model.table_name)
        .and_return(generated_sql)
      mock_model.ask(natural_query)
    end

    context "when API key is not configured" do
      before do
        Modelm.configuration.llm_api_key = nil
      end
      it "raises ConfigurationError" do
        expect { mock_model.ask(natural_query) }.to raise_error(Modelm::ConfigurationError, "LLM API key is not configured for Modelm.")
      end
    end

    context "when schema file is not found" do
      before do
        FileUtils.rm_f(Modelm.configuration.db_schema_path) # Remove the schema file
        # Ensure Rails is not defined for this specific test path to avoid system call attempt
        hide_const("Rails") if defined?(Rails)
      end
      it "raises ConfigurationError if not in Rails and schema missing" do 
        expect { mock_model.ask(natural_query) }.to raise_error(Modelm::ConfigurationError, /Database schema file not found at spec\/fixtures\/schema.rb. Modelm needs schema context/)
      end
    end
    
    context "when schema file is found but empty" do
      before do
        File.write(Modelm.configuration.db_schema_path, "  \n  ") # Write empty content
      end
      it "raises ConfigurationError" do
        expect { mock_model.ask(natural_query) }.to raise_error(Modelm::ConfigurationError, "Schema content is empty. Cannot proceed without database schema context.")
      end
    end

    context "when in Rails environment and schema file is missing initially" do
      let(:rails_schema_path) { "db/schema.rb" }
      before do
        # Simulate being in a Rails environment
        stub_const("Rails", Class.new) unless defined?(Rails)
        allow(mock_model).to receive(:system).and_return(true) # Stub system calls like `bin/rails db:schema:dump` to succeed
        
        Modelm.configuration.db_schema_path = rails_schema_path
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
        
        expect(llm_service_double).to receive(:generate_sql).with(natural_query, schema_content, mock_model.table_name).and_return(generated_sql)
        mock_model.ask(natural_query)
      end

      it "attempts to dump schema and reads structure.sql if schema.rb fails but structure.sql exists" do
        alt_schema_path = "db/structure.sql"
        expect(mock_model).to receive(:system).with("bin/rails db:schema:dump").ordered.and_return(true)
        allow(File).to receive(:exist?).with(rails_schema_path).and_return(false, false) 
        allow(File).to receive(:exist?).with(alt_schema_path).and_return(true) 
        allow(File).to receive(:read).with(alt_schema_path).and_return(schema_content)

        expect(llm_service_double).to receive(:generate_sql).with(natural_query, schema_content, mock_model.table_name).and_return(generated_sql)
        mock_model.ask(natural_query)
      end

      it "raises ConfigurationError if schema dump fails and no schema file is found" do
        expect(mock_model).to receive(:system).with("bin/rails db:schema:dump").ordered.and_return(true)
        allow(File).to receive(:exist?).with(rails_schema_path).and_return(false, false) 
        allow(File).to receive(:exist?).with("db/structure.sql").and_return(false)

        expect { mock_model.ask(natural_query) }.to raise_error(Modelm::ConfigurationError, /Database schema file not found at db\/schema.rb or db\/structure.sql even after attempting to dump/)
      end
    end
  end
end

# Test the main Modelm module itself
RSpec.describe Modelm do
  before do
    Modelm.configuration = nil
  end

  describe ".configure" do
    it "yields a Configuration object" do
      expect { |b| Modelm.configure(&b) }.to yield_with_args(be_a(Modelm::Configuration))
    end

    it "assigns the configured object to Modelm.configuration" do
      Modelm.configure do |config|
        config.llm_api_key = "configured_key"
      end
      expect(Modelm.configuration).to be_a(Modelm::Configuration)
      expect(Modelm.configuration.llm_api_key).to eq("configured_key")
    end

    it "uses existing configuration if called multiple times" do
      Modelm.configure { |c| c.llm_api_key = "first_key" }
      first_config_object_id = Modelm.configuration.object_id
      Modelm.configure { |c| c.llm_model_name = "new_model" }
      expect(Modelm.configuration.object_id).to eq(first_config_object_id)
      expect(Modelm.configuration.llm_api_key).to eq("first_key")
      expect(Modelm.configuration.llm_model_name).to eq("new_model")
    end
  end

  describe ".included" do
    let(:base_class) { Class.new }
    it "extends the base class with Model::ClassMethods" do
      expect(base_class).not_to respond_to(:ask) # Check before inclusion
      Modelm.included(base_class)
      expect(base_class).to respond_to(:ask)
      expect(base_class).to respond_to(:modelm)
    end
  end
end

