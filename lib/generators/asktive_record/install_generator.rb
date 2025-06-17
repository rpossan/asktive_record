# frozen_string_literal: true

require "rails/generators/base"

module AsktiveRecord
  module Generators
    # InstallGenerator is a Rails generator that copies the initializer file
    # for AsktiveRecord into the Rails application's config/initializers directory.
    # This allows users to configure the LLM provider, API key, model name, and
    # database schema path for AsktiveRecord.
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      def copy_initializer_file
        template "asktive_record_initializer.rb", "config/initializers/asktive_record.rb"
      end
    end
  end
end
