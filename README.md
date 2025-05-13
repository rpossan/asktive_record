# Modelm: Natural Language Database Querying for Ruby on Rails

[![Gem Version](https://badge.fury.io/rb/modelm.svg)](https://badge.fury.io/rb/modelm) <!-- Placeholder: Update once published -->
[![Build Status](https://github.com/rpossan/modelm/actions/workflows/main.yml/badge.svg)](https://github.com/rpossan/modelm/actions/workflows/main.yml) <!-- Placeholder: Update with correct repo path -->

**Modelm** is a Ruby gem designed to bridge the gap between human language and database queries. It integrates with Large Language Models (LLMs) like OpenAI's ChatGPT to allow developers to query their Rails application's database using natural language.

Imagine your users (or even you, the developer!) asking questions like "*Show me the last five users who signed up*" or "*Which products had the most sales last month?*" and getting back the actual data, powered by an LLM translating these questions into SQL.

## Features

*   **Natural Language to SQL**: Convert human-readable questions into SQL queries.
*   **LLM Integration**: Currently supports OpenAI's ChatGPT, with a design that allows for future expansion to other LLMs (e.g., Gemini).
*   **Rails Integration**: Seamlessly integrates with your Active Record models.
*   **Database Schema Awareness**: Uploads your database schema to the LLM for context-aware query generation.
*   **Developer Control**: Provides a two-step query process: first, get the LLM-generated SQL, then sanitize and execute it, giving you full control over what runs against your database.
*   **Easy Setup**: Simple CLI commands to install and configure the gem in your Rails project.
*   **Customizable Configuration**: Set your LLM provider, API keys, and model preferences through an initializer.

## How It Works

1.  **Setup**: You install the gem and run a setup command. This command can read your `db/schema.rb` (or `db/structure.sql`) and (in future versions or specific LLM integrations) make the LLM aware of your database structure.
2.  **Configuration**: You configure your LLM API key and preferences in an initializer file.
3.  **Querying**: In your Rails model (e.g., `User`), you can call `User.ask("your natural language query")`.
4.  **LLM Magic**: Modelm sends your query and the relevant schema context to the configured LLM.
5.  **SQL Generation**: The LLM returns a SQL query.
6.  **Safety First**: The `ask` method returns a `Modelm::Query` object containing the raw SQL. You can then inspect this SQL, apply sanitization rules (e.g., ensure it's only a `SELECT` statement), and then explicitly execute it.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'modelm'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install modelm
```

## Getting Started

After installing the gem, you need to run the installer to generate the configuration file:

```bash
$ bundle exec rails generate modelm:install
# or, if you're not in a full Rails app context for the generator (less common for this gem):
# $ bundle exec modelm:install (This might require further setup for standalone use)
```

This will create an initializer file at `config/initializers/modelm.rb`.

### Configure Modelm

Open `config/initializers/modelm.rb` and configure your LLM provider and API key:

```ruby
Modelm.configure do |config|
  # === LLM Provider ===
  # Specify the LLM provider to use. Default is :openai
  # Supported providers: :openai (more can be added in the future)
  # config.llm_provider = :openai

  # === LLM API Key ===
  # Set your API key for the chosen LLM provider.
  # It is strongly recommended to use environment variables for sensitive data.
  # For example, for OpenAI:
  # config.llm_api_key = ENV["OPENAI_API_KEY"]
  config.llm_api_key = "YOUR_OPENAI_API_KEY_HERE" # Replace with your actual key or ENV variable

  # === LLM Model Name ===
  # Specify the model name for the LLM provider if applicable.
  # For OpenAI, default is "gpt-3.5-turbo". Other models like "gpt-4" can be used.
  # config.llm_model_name = "gpt-3.5-turbo"

  # === Database Schema Path ===
  # Path to your Rails application's schema file (usually schema.rb or structure.sql).
  # This is used by the `modelm:setup` command and the `.ask` method to provide context to the LLM.
  # Default is "db/schema.rb".
  # config.db_schema_path = "db/schema.rb"
end
```

**Important**: Securely manage your API keys. Using environment variables (e.g., `ENV["OPENAI_API_KEY"]`) is highly recommended.

### Prepare Schema for LLM

Run the setup command to help Modelm understand your database structure. This command attempts to read your schema file (e.g., `db/schema.rb`).

```bash
$ bundle exec rails generate modelm:setup
# or
# $ bundle exec modelm:setup
```

This step ensures that the LLM has the necessary context about your tables and columns to generate accurate SQL queries. The schema content is passed with each query to the LLM in the current version.

## Usage

First, include Modelm's functionality in your Active Record models where you want to use natural language querying. You can do this in `ApplicationRecord` to make it available globally, or in specific models.

```ruby
# app/models/application_record.rb
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
  include Modelm # Include the main Modelm module
end
```

Then, in your specific model, call the `modelm` class method to activate its features for that model (this step might become implicit in future versions if `include Modelm` is sufficient):

```ruby
# app/models/user.rb
class User < ApplicationRecord
  modelm # Activates Modelm for the User model
end
```

Now you can use the `.ask()` method:

```ruby
# Example in a Rails console, controller, or service object:

# 1. Ask a question in natural language
natural_query = "I want to know the last five users who signed up for my app"
modelm_query = User.ask(natural_query)

# modelm_query is now a Modelm::Query object
puts "LLM Generated SQL: #{modelm_query.raw_sql}"
# => LLM Generated SQL: SELECT * FROM users ORDER BY created_at DESC LIMIT 5

# 2. (Recommended) Sanitize the query
# By default, it checks if it's a SELECT query. You can add more rules.
begin
  modelm_query.sanitize! # Raises Modelm::SanitizationError if it's not a SELECT query by default
  puts "Sanitized SQL: #{modelm_query.sanitized_sql}"
rescue Modelm::SanitizationError => e
  puts "Error: #{e.message}"
  # Handle error, maybe log it or don't execute the query
  return
end

# 3. Execute the query
begin
  users = modelm_query.execute
  # users will be an array of User records (if using ActiveRecord's find_by_sql implicitly)
  # or an array of hashes depending on the execution context.
  users.each do |user|
    puts "User ID: #{user.id}, Email: #{user.email}, Signed Up: #{user.created_at}"
  end
rescue Modelm::QueryExecutionError => e
  puts "Error executing query: #{e.message}"
  # Handle database execution errors
end
```

### The `Modelm::Query` Object

The `YourModel.ask()` method returns an instance of `Modelm::Query`. This object has a few useful methods:

*   `raw_sql`: The raw SQL string generated by the LLM.
*   `sanitized_sql`: The SQL string after `sanitize!` has been called. Initially, it's the same as `raw_sql`.
*   `sanitize!(allow_only_select: true)`: Performs sanitization. By default, it ensures the query is a `SELECT` statement. Raises `Modelm::SanitizationError` on failure. Returns `self` for chaining.
*   `execute`: Executes the `sanitized_sql` against the database using the model's underlying connection (e.g., `YourModel.find_by_sql`). Returns the query results.
*   `to_s`: Returns the `sanitized_sql` (or `raw_sql` if `sanitized_sql` hasn't been modified from raw).

## Supported LLMs

*   **Currently**: OpenAI (ChatGPT models like `gpt-3.5-turbo`, `gpt-4`).
*   **Future**: The gem is designed to be extensible. Support for other LLMs (like Google's Gemini) can be added by creating new LLM service adapters.

## Contributing

Contributions are welcome! Whether it's bug reports, feature requests, documentation improvements, or code contributions, please feel free to open an issue or submit a pull request on GitHub.

1.  Fork the repository ([https://github.com/rpossan/modelm/fork](https://github.com/rpossan/modelm/fork)).
2.  Create your feature branch (`git checkout -b my-new-feature`).
3.  Commit your changes (`git commit -am 'Add some feature'`).
4.  Push to the branch (`git push origin my-new-feature`).
5.  Create a new Pull Request.

Please make sure to add tests for your changes and ensure all tests pass (`bundle exec rspec`). Also, adhere to the existing code style (you can use RuboCop: `bundle exec rubocop`).

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bundle exec rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Modelm project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

---

*This gem was proudly developed with the assistance of an AI agent.* Author: [rpossan](https://github.com/rpossan)

