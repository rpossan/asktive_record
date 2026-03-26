# frozen_string_literal: true

require_relative "lib/asktive_record/version"

Gem::Specification.new do |spec|
  spec.name = "asktive_record"
  spec.version = AsktiveRecord::VERSION
  spec.authors = ["rpossan"]
  spec.email = ["ronaldo.possan@gmail.com"]

  spec.summary = "A Ruby gem that lets your data answer like a human using LLM"
  spec.description = "AsktiveRecord bridges human language and database queries. " \
                     "It lets you interact with your Rails database as if you were " \
                     "having a conversation with a knowledgeable assistant. " \
                     "Instead of writing SQL or chaining ActiveRecord methods, " \
                     "you simply ask questions in plain English (or any language) " \
                     "and get clear, human-friendly answers powered by LLMs."
  spec.homepage = "https://github.com/rpossan/asktive_record"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/rpossan/asktive_record"
  spec.metadata["changelog_uri"] = "https://github.com/rpossan/asktive_record/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile plans/])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "railties", ">= 7.0"
  spec.add_dependency "ruby-openai", "~> 8.1"

  spec.add_development_dependency "bundler", ">= 2.4"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
