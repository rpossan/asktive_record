# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Template content" do
  it "contains correct initialization code" do
    path = File.expand_path("../../lib/generators/asktive_record/templates/asktive_record_initializer.rb", __dir__)

    content = File.read(path)

    expect(content).to include("AsktiveRecord.configure do |config|")
    expect(content).to include('config.llm_api_key = ENV["OPENAI_API_KEY"]')
    expect(content).not_to include("YOUR_OPENAI_API_KEY_HERE")
  end
end
