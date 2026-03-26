# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Template content" do
  let(:content) do
    path = File.expand_path("../../lib/generators/asktive_record/templates/asktive_record_initializer.rb", __dir__)
    File.read(path)
  end

  it "contains correct initialization code" do
    expect(content).to include("AsktiveRecord.configure do |config|")
    expect(content).to include('config.llm_api_key = ENV.fetch("OPENAI_API_KEY", nil)')
    expect(content).not_to include("YOUR_OPENAI_API_KEY_HERE")
  end

  it "documents adapter pattern configuration" do
    expect(content).to include("config.adapter")
    expect(content).to include("AsktiveRecord::Adapters::Base")
  end

  it "documents temperature and max_tokens options" do
    expect(content).to include("config.temperature")
    expect(content).to include("config.max_tokens")
  end
end
