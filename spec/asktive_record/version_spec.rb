require "spec_helper"
require_relative "../../lib/asktive_record/version"

RSpec.describe AsktiveRecord do
  it "has a version number" do
    expect(AsktiveRecord::VERSION).not_to be_nil
    expect(AsktiveRecord::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end
end
