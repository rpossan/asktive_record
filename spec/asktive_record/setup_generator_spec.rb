# frozen_string_literal: true

require "rails/generators"
require "generator_spec"
require "generators/asktive_record/setup_generator"

RSpec.describe AsktiveRecord::Generators::SetupGenerator, type: :generator do
  destination File.expand_path("../tmp", __dir__)

  let(:schema_path) { File.join(destination_root, "db/schema.rb") }
  let(:structure_sql_path) { File.join(destination_root, "db/structure.sql") }

  before(:all) do
    prepare_destination
    FileUtils.mkdir_p(File.join(destination_root, "db"))
  end

  after(:each) do
    FileUtils.rm_f(schema_path)
    FileUtils.rm_f(structure_sql_path)
  end

  it "prints a message if not in a Rails app and schema file does not exist" do
    allow(Object).to receive(:defined?).with(Rails).and_return(false)
    expect do
      described_class.start
    end.to output(%r{Could not find schema file at db/schema.rb}).to_stdout
  end

  # it "executes to a non rails app with custom schema file" do
  #   temp_structure_sql_path = File.expand_path("../../db/structure.sql", __dir__)
  #   File.write(temp_structure_sql_path, "SQL dump content")

  #   allow(Object).to receive(:defined?).with(Rails).and_return(false)
  #   expect do
  #     described_class.start
  #   end.to output(%r{Could not find schema file at db/schema.rb}).to_stdout
  # ensure
  #   FileUtils.rm_f(temp_structure_sql_path)
  # end

  it "reads schema.rb if present and not in Rails" do
    allow(Object).to receive(:defined?).with(Rails).and_return(false)
    File.write(schema_path, "ActiveRecord::Schema.define(version: 2024)")
    stub_const("AsktiveRecord::Generators::SetupGenerator::AsktiveRecord",
               double(configuration: double(db_schema_path: schema_path)))
    expect do
      described_class.start
    end.to output(/Successfully read schema from/).to_stdout
  end

  it "reads structure.sql if schema.rb is missing and not in Rails" do
    allow(Object).to receive(:defined?).with(Rails).and_return(false)
    File.write(structure_sql_path, "CREATE TABLE users (id integer);")
    stub_const("AsktiveRecord::Generators::SetupGenerator::AsktiveRecord",
               double(configuration: double(db_schema_path: schema_path)))
    expect do
      described_class.start
    end.to output(/Attempting to dump database schema using 'rails db:schema:dump/).to_stdout
  end

  it "runs rails db:schema:dump and reads schema.rb in Rails context" do
    fake_rails = double
    stub_const("Rails", fake_rails)
    allow(Object).to receive(:defined?).with(Rails).and_return(true)
    allow_any_instance_of(Object).to receive(:system).with("bin/rails db:schema:dump").and_return(true)
    File.write(schema_path, "ActiveRecord::Schema.define(version: 2024)")
    stub_const("AsktiveRecord::Generators::SetupGenerator::AsktiveRecord",
               double(configuration: double(db_schema_path: schema_path)))
    expect do
      described_class.start
    end.to output(/Attempting to dump database schema/).to_stdout
  end
  it "prints error if rails db:schema:dump fails" do
    fake_rails = double
    stub_const("Rails", fake_rails)
    allow(Object).to receive(:defined?).with(Rails).and_return(true)
    allow_any_instance_of(Object).to receive(:system).with("bin/rails db:schema:dump").and_raise(StandardError.new("fail"))
    stub_const("AsktiveRecord::Generators::SetupGenerator::AsktiveRecord",
               double(configuration: double(db_schema_path: schema_path)))
    expect do
      described_class.start
    end.to output(/Failed to execute 'rails db:schema:dump'/).to_stdout
  end

  it "prints a message if not in a Rails app and structure.sql does not exist" do
    Object.send(:remove_const, :Rails) if Object.const_defined?(:Rails)
    # Ensure neither schema.rb nor structure.sql exist
    FileUtils.rm_f(schema_path)
    FileUtils.rm_f(structure_sql_path)
    stub_const("AsktiveRecord::Generators::SetupGenerator::AsktiveRecord",
               double(configuration: double(db_schema_path: schema_path)))
    expect do
      described_class.start
    end.to output(/This command should be run within a Rails application/).to_stdout
  end

  it "prints a message if not in a Rails app and structure.sql exist" do
    Object.send(:remove_const, :Rails) if Object.const_defined?(:Rails)
    # FileUtils.rm_f(schema_path)
    # FileUtils.rm_f(structure_sql_path)
    File.write(schema_path, "ActiveRecord::Schema.define(version: 2024)")
    stub_const("AsktiveRecord::Generators::SetupGenerator::AsktiveRecord",
               double(configuration: double(db_schema_path: schema_path)))
    expect do
      described_class.start
    end.to output(/This command should be run within a Rails application/).to_stdout
  end
end
