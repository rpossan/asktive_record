require 'rails/generators/base'

module Modelm
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      def copy_initializer_file
        template "modelm_initializer.rb", "config/initializers/modelm.rb"
      end
    end
  end
end

