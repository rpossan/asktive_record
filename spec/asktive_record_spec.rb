# frozen_string_literal: true

require "spec_helper"

RSpec.describe AsktiveRecord do
  it "has a version number" do
    expect(AsktiveRecord::VERSION).not_to be nil
  end

  it "extends service classes with Service::ClassMethods when included in a class inheriting from Object" do
    service_class = Class.new do
      include AsktiveRecord
    end
    expect(service_class.singleton_class.included_modules).to include(AsktiveRecord::Service::ClassMethods)
  end

  it "extends model classes with Model::ClassMethods when included in a subclass" do
    parent_class = Class.new
    model_class = Class.new(parent_class) do
      include AsktiveRecord
    end
    expect(model_class.singleton_class.included_modules).to include(AsktiveRecord::Model::ClassMethods)
  end
end
