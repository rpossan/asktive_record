# frozen_string_literal: true

require "spec_helper"
require "asktive_record/query"
require "asktive_record/error"

# Mock ActiveRecord::Base and its connection for testing execution
module ActiveRecord
  class Base
    def self.connected?
      true # Assume connected for tests
    end

    def self.connection
      @connection ||= Connection.new
    end

    class Connection
      def select_all(sql)
        # Simulate returning an ActiveRecord::Result-like object (array of hashes)
        [{ "id" => 1, "name" => "Test Result" }] if sql.include?("SELECT")
      end

      def execute(sql)
        # Simulate executing non-SELECT queries
        true unless sql.include?("SELECT")
      end
    end
  end
end

# Mock a model class that responds to find_by_sql
class MockModel
  def self.find_by_sql(sql)
    # Simulate returning model instances
    [new] if sql.include?("SELECT")
  end

  def self.table_name
    "mock_models"
  end
end

# Mock a service class that does NOT respond to find_by_sql
class MockServiceClass
  # Does not have find_by_sql
end

RSpec.describe AsktiveRecord::Query do
  let(:raw_sql) { "SELECT * FROM users WHERE id = 1" }
  let(:non_select_sql) { "UPDATE users SET name = \"Test\" WHERE id = 1" }
  let(:model_class) { MockModel }
  let(:service_class) { MockServiceClass }
  let(:query_for_model) { described_class.new(raw_sql, model_class) }
  let(:query_for_service) { described_class.new(raw_sql, service_class) }
  let(:non_select_query_for_service) { described_class.new(non_select_sql, service_class) }

  describe "#initialize" do
    it "stores the raw SQL and model class" do
      expect(query_for_model.raw_sql).to eq(raw_sql)
      expect(query_for_model.model_class).to eq(model_class)
    end

    it "initializes sanitized_sql with raw_sql" do
      expect(query_for_model.sanitized_sql).to eq(raw_sql)
    end
  end

  describe "#sanitize!" do
    it "does nothing if the query is a SELECT statement and allow_only_select is true" do
      expect { query_for_model.sanitize!(allow_only_select: true) }.not_to raise_error
      expect(query_for_model.sanitized_sql).to eq(raw_sql)
    end

    it "raises SanitizationError if the query is not SELECT and allow_only_select is true" do
      query = described_class.new("UPDATE users SET name = \"Test\"", model_class)
      expect do
        query.sanitize!(allow_only_select: true)
      end.to raise_error(AsktiveRecord::SanitizationError,
                         /Only SELECT statements are allowed/)
    end

    it "allows non-SELECT queries if allow_only_select is false" do
      query = described_class.new("UPDATE users SET name = \"Test\"", model_class)
      expect { query.sanitize!(allow_only_select: false) }.not_to raise_error
      expect(query.sanitized_sql).to eq("UPDATE users SET name = \"Test\"")
    end

    it "returns self for chaining" do
      expect(query_for_model.sanitize!).to eq(query_for_model)
    end
  end

  describe "#execute" do
    context "when associated class responds to find_by_sql (e.g., ActiveRecord model)" do
      before { query_for_model.sanitize! }

      it "calls find_by_sql on the model class with sanitized_sql" do
        expect(model_class).to receive(:find_by_sql).with(query_for_model.sanitized_sql).and_call_original
        query_for_model.execute
      end

      it "returns the result from find_by_sql" do
        results = query_for_model.execute
        expect(results).to be_an(Array)
        expect(results.first).to be_a(MockModel)
      end
    end

    context "when associated class does not respond to find_by_sql (e.g., service class)" do
      before { query_for_service.sanitize! }

      it "uses ActiveRecord::Base.connection.select_all for SELECT queries" do
        expect(ActiveRecord::Base.connection).to receive(:select_all).with(query_for_service.sanitized_sql).and_call_original
        query_for_service.execute
      end

      it "returns an array of hashes from select_all" do
        results = query_for_service.execute
        expect(results).to be_an(Array)
        expect(results.first).to be_a(Hash)
        expect(results.first["name"]).to eq("Test Result")
      end

      context "with non-SELECT query (if sanitization allows)" do
        before do
          non_select_query_for_service.sanitize!(allow_only_select: false)
        end

        it "uses ActiveRecord::Base.connection.execute" do
          expect(ActiveRecord::Base.connection).to receive(:execute).with(non_select_query_for_service.sanitized_sql).and_call_original
          non_select_query_for_service.execute
        end
      end
    end

    context "when ActiveRecord::Base is not available or not connected" do
      before do
        query_for_service.sanitize!
        # Hide ActiveRecord::Base for this context
        hide_const("ActiveRecord::Base")
      end

      it "raises QueryExecutionError" do
        expect do
          query_for_service.execute
        end.to raise_error(AsktiveRecord::QueryExecutionError,
                           /Cannot execute query. The associated class \(MockServiceClass\) does not respond to :find_by_sql, and no active ActiveRecord::Base connection was found./)
      end
    end

    context "when database execution fails" do
      before do
        query_for_model.sanitize!
        allow(model_class).to receive(:find_by_sql).and_raise(StandardError, "Database error")
      end

      it "raises QueryExecutionError" do
        expect do
          query_for_model.execute
        end.to raise_error(AsktiveRecord::QueryExecutionError, /Failed to execute SQL query: Database error/)
      end
    end
  end

  describe "#to_s" do
    it "returns the sanitized_sql if available" do
      query_for_model.sanitized_sql = "SELECT id FROM users"
      expect(query_for_model.to_s).to eq("SELECT id FROM users")
    end

    it "returns the raw_sql if sanitized_sql is nil (before sanitization)" do
      query = described_class.new(raw_sql, model_class)
      query.sanitized_sql = nil # Simulate state before sanitize! is called or if it resets
      expect(query.to_s).to eq(raw_sql)
    end
  end
end
