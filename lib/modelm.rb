require "modelm/version"
require "modelm/error"
require "modelm/configuration"
require "modelm/model"
require "modelm/query"

module Modelm
  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end

  # Main entry point for ApplicationRecord to include Modelm behavior
  def self.included(base)
    base.extend(Model::ClassMethods)
  end
end

