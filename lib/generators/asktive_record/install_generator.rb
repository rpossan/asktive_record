require "rails/generators/base"

module AsktiveRecord
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      def copy_initializer_file
        template "asktive_record_initializer.rb", "config/initializers/asktive_record.rb"
      end
    end
  end
end
