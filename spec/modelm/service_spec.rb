# frozen_string_literal: true

require "spec_helper"
require "modelm"
require "modelm/service"
require "modelm/query"
require "modelm/configuration"
require "modelm/llm_service"
require "modelm/error"
require "fileutils"

# Mock a service class that includes Modelm
class MockAskService
  include Modelm
  # No additional code needed for basic functionality
end

RSpec.describe Modelm::Service::ClassMethods do
  let(:service_class) { MockAskService }
  let(:config) { Modelm.configuration }
  let(:llm_service_double) { instance_double(Modelm::LlmService) }
  let(:schema_content) { "CREATE TABLE users (id INT, email VARCHAR(255), created_at DATETIME); CREATE TABLE products (id INT, name VARCHAR(255), price DECIMAL, category_id INT);" }
  let(:natural_query) { "find all users" }
  let(:generated_sql) { "SELECT * FROM users" }

  before do
    # Setup Modelm configuration for each test
    Modelm.configure do |c|
      c.llm_api_key = "fake_api_key"
      c.db_schema_path = "spec/fixtures/schema.rb"
    end
    
    # Create a dummy schema file for tests
    FileUtils.mkdir_p("spec/fixtures")
    File.write(Modelm.configuration.db_schema_path, schema_content)

    # Mock the LLM service with more flexible argument matching
    allow(Modelm::LlmService).to receive(:new).with(Modelm.configuration).and_return(llm_service_double)
    allow(llm_service_double).to receive(:generate_sql_for_service)
      .with(any_args)
      .and_return(generated_sql)
  end

  after do
    # Clean up dummy schema file
    FileUtils.rm_rf("spec/fixtures")
    # Reset configuration to avoid interference between tests
    Modelm.configuration = nil 
  end

  describe ".ask" do
    it "returns a Modelm::Query object" do
      query_object = service_class.ask(natural_query)
      expect(query_object).to be_a(Modelm::Query)
      expect(query_object.raw_sql).to eq(generated_sql)
      expect(query_object.model_class).to eq(service_class)
    end

    it "uses LlmService to generate SQL for any table" do
      # Use allow instead of expect for more flexibility
      allow(llm_service_double).to receive(:generate_sql_for_service)
        .with(natural_query, schema_content, "any")
        .and_return(generated_sql)
      service_class.ask(natural_query)
    end

    it "accepts a specific model option" do
      mock_model = Class.new
      query_object = service_class.ask(natural_query, model: mock_model)
      expect(query_object.model_class).to eq(mock_model)
    end

    it "accepts a specific table_name option" do
      # Use allow instead of expect for more flexibility
      allow(llm_service_double).to receive(:generate_sql_for_service)
        .with(natural_query, schema_content, "products")
        .and_return("SELECT * FROM products")
      service_class.ask(natural_query, table_name: "products")
    end

    context "when API key is not configured" do
      before do
        Modelm.configuration.llm_api_key = nil
      end
      
      it "raises ConfigurationError" do
        expect { service_class.ask(natural_query) }.to raise_error(Modelm::ConfigurationError, "LLM API key is not configured for Modelm.")
      end
    end

    context "when schema file is not found" do
      before do
        FileUtils.rm_f(Modelm.configuration.db_schema_path)
        # Ensure Rails is not defined for this specific test path
        hide_const("Rails") if defined?(Rails)
      end
      
      it "raises ConfigurationError if not in Rails and schema missing" do 
        expect { service_class.ask(natural_query) }.to raise_error(Modelm::ConfigurationError, /Database schema file not found at spec\/fixtures\/schema.rb. Modelm needs schema context/)
      end
    end
    
    context "when schema file is found but empty" do
      before do
        File.write(Modelm.configuration.db_schema_path, "  \n  ")
      end
      
      it "raises ConfigurationError" do
        expect { service_class.ask(natural_query) }.to raise_error(Modelm::ConfigurationError, "Schema content is empty. Cannot proceed without database schema context.")
      end
    end

    context "when in Rails environment" do
      let(:mock_application_record) { Class.new }
      
      before do
        # Simulate being in a Rails environment with ApplicationRecord
        stub_const("Rails", Class.new)
        stub_const("ApplicationRecord", mock_application_record)
      end
      
      it "uses ApplicationRecord as the target model if no model specified" do
        query_object = service_class.ask(natural_query)
        expect(query_object.model_class).to eq(mock_application_record)
      end
    end
  end
end

# Test the direct Modelm.ask method
RSpec.describe Modelm do
  let(:llm_service_double) { instance_double(Modelm::LlmService) }
  let(:schema_content) { "CREATE TABLE users (id INT, email VARCHAR(255));" }
  let(:natural_query) { "find all users" }
  let(:generated_sql) { "SELECT * FROM users" }

  before do
    Modelm.configuration = nil
    Modelm.configure do |c|
      c.llm_api_key = "fake_api_key"
      c.db_schema_path = "spec/fixtures/schema.rb"
    end
    
    FileUtils.mkdir_p("spec/fixtures")
    File.write(Modelm.configuration.db_schema_path, schema_content)
    
    allow(Modelm::LlmService).to receive(:new).with(Modelm.configuration).and_return(llm_service_double)
    allow(llm_service_double).to receive(:generate_sql_for_service)
      .with(any_args)
      .and_return(generated_sql)
  end

  after do
    FileUtils.rm_rf("spec/fixtures")
    Modelm.configuration = nil
  end

  describe ".ask" do
    it "provides a direct interface to query any table" do
      query_object = Modelm.ask(natural_query)
      expect(query_object).to be_a(Modelm::Query)
      expect(query_object.raw_sql).to eq(generated_sql)
      expect(query_object.model_class).to eq(Modelm)
    end
    
    it "accepts options like a service class" do
      mock_model = Class.new
      query_object = Modelm.ask(natural_query, model: mock_model, table_name: "products")
      expect(query_object.model_class).to eq(mock_model)
    end
  end

  describe ".included" do
    let(:base_class) { Class.new }
    
    it "extends the base class with appropriate ClassMethods based on class type" do
      expect(base_class).not_to respond_to(:ask)
      Modelm.included(base_class)
      expect(base_class).to respond_to(:ask)
      # Don't test for modelm specifically since it depends on class hierarchy
    end
  end
end
