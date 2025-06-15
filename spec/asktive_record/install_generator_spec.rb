# frozen_string_literal: true

require "rails/generators"
require "generator_spec"
require "generators/asktive_record/install_generator"

RSpec.describe AsktiveRecord::Generators::InstallGenerator, type: :generator do
  destination File.expand_path("../tmp", __dir__)

  before(:all) do
    prepare_destination
  end

  describe "generator runs successfully" do
    before(:all) do
      run_generator
    end

    it "creates the initializer file" do
      expect(File.exist?(File.join(destination_root, "config/initializers/asktive_record.rb"))).to be true
    end

    it "copies the correct template content" do
      template_path = File.expand_path("../../lib/generators/asktive_record/templates/asktive_record_initializer.rb",
                                       __dir__)
      expected_content = File.read(template_path) if File.exist?(template_path)
      actual_content = File.read("#{destination_root}/config/initializers/asktive_record.rb")
      expect(actual_content).to eq(expected_content) if expected_content
    end
  end
end
