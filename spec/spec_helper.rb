# frozen_string_literal: true

require "debug"
require "simplecov"
SimpleCov.start do
  enable_coverage :branch
  add_filter "/spec/" # Exclude spec files from coverage
  add_filter "lib/asktive_record/version.rb" # Exclude version file from coverage
  add_filter "lib/generators/asktive_record/templates/asktive_record_initializer.rb" # Exclude generator template from coverage

  track_files "lib/**/*.rb" # ✅ Explicitly track your gem source
end

require "asktive_record"
RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
