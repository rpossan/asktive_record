# Modelm: Natural Language Database Querying for Ruby on Rails

[![Gem Version](https://badge.fury.io/rb/modelm.svg)](https://badge.fury.io/rb/modelm) <!-- Placeholder: Update once published -->
[![Build Status](https://github.com/rpossan/modelm/actions/workflows/main.yml/badge.svg)](https://github.com/rpossan/modelm/actions/workflows/main.yml) <!-- Placeholder: Update with correct repo path -->

**Modelm** is a Ruby gem designed to bridge the gap between human language and database queries. It integrates with Large Language Models (LLMs) like OpenAI's ChatGPT to allow developers to query their Rails application's database using natural language.

Imagine your users (or even you, the developer!) asking questions like "*Show me the last five users who signed up*" or "*Which products had the most sales last month?*" and getting back the actual data, powered by an LLM translating these questions into SQL.

## Features

*   **Natural Language to SQL**: Convert human-readable questions into SQL queries.
*   **LLM Integration**: Currently supports OpenAI's ChatGPT, with a design that allows for future expansion to other LLMs (e.g., Gemini).
*   **Flexible Querying Options**:
    *   Use with specific models (e.g., `User.ask("query")`)
    *   Use with service classes to query any table (e.g., `AskService.ask("query")`)
*   **Database Schema Awareness**: Uploads your database schema to the LLM for context-aware query generation.
*   **Developer Control**: Provides a two-step query process: first, get the LLM-generated SQL, then sanitize and execute it, giving you full control over what runs against your database.
*   **Smart Execution**: Automatically uses the appropriate execution method (`find_by_sql` for models, `ActiveRecord::Base.connection` for service classes).
*   **Easy Setup**: Simple CLI commands to install and configure the gem in your Rails project.
*   **Customizable Configuration**: Set your LLM provider, API keys, and model preferences through an initializer.

## How It Works

1.  **Setup**: You install the gem and run a setup command. This command can read your `db/schema.rb` (or `db/structure.sql`) and make the LLM aware of your database structure.
2.  **Configuration**: You configure your LLM API key and preferences in an initializer file.
3.  **Querying**: You can query your database in two ways:
    *   Model-specific: `User.ask("your natural language query")`
    *   Service-based (any table): `AskService.ask("your natural language query")`
4.  **LLM Magic**: Modelm sends your query and the relevant schema context to the configured LLM.
5.  **SQL Generation**: The LLM returns a SQL query.
6.  **Safety First**: The `ask` method returns a `Modelm::Query` object containing the raw SQL. You can then inspect this SQL, apply sanitization rules (e.g., ensure it's only a `SELECT` statement), and then explicitly execute it.
7.  **Execution**: The `execute` method intelligently runs the sanitized SQL. If the query originated from a model (like `User.ask`), it uses `User.find_by_sql`. If it originated from a service class (like `AskService.ask`), it uses the general `ActiveRecord::Base.connection` to execute the query, returning an array of hashes for `SELECT` statements.

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

Modelm offers two ways to query your database using natural language:

### 1. Model-Specific Querying

This approach ties queries to specific models, ideal when you know which table you want to query.

```ruby
# First, include Modelm in your ApplicationRecord or specific models
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
  # Include Modelm here if you want all models to have the .ask method
  # include Modelm 
end

# Then, in your specific model, activate Modelm
class User < ApplicationRecord
  include Modelm # Include the module
  modelm # Activate model-specific setup (optional, future use)
end

# Now you can query the User model directly
natural_query = "Find the last five users who signed up"
modelm_query = User.ask(natural_query)
# => Returns a Query object with SQL targeting the users table
```

### 2. Service-Class Querying (Any Table)

This approach allows querying any table or multiple tables with joins, ideal for more complex queries or when you want a central service to handle all natural language queries.

```ruby
# Create a service class that includes Modelm
class AskService
  include Modelm
  # No additional code needed!
end

# Now you can query any table through this service
natural_query = "Which is the last user created?"
modelm_query = AskService.ask(natural_query)
# => Returns a Query object with SQL targeting the users table

natural_query = "Which is the cheapest product?"
modelm_query = AskService.ask(natural_query)
# => Returns a Query object with SQL targeting the products table

natural_query = "Show me products with their categories"
modelm_query = AskService.ask(natural_query)
# => Returns a Query object with SQL that might include JOINs between products and categories
```

You can also use Modelm directly for one-off queries:

```ruby
natural_query = "Show me all active subscriptions with their users"
modelm_query = Modelm.ask(natural_query)
```

### Working with Query Results

Regardless of which approach you use, you'll get a `Modelm::Query` object that you can work with:

```ruby
# 1. Get the generated SQL
puts "LLM Generated SQL: #{modelm_query.raw_sql}"
# => LLM Generated SQL: SELECT * FROM users ORDER BY created_at DESC LIMIT 5

# 2. (Recommended) Sanitize the query
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
  results = modelm_query.execute
  # Process the results
  # - If executed via a model (e.g., User.ask), results will be an array of User objects.
  # - If executed via a service class (e.g., AskService.ask), results will be an array of Hashes (from ActiveRecord::Result).
  results.each do |record|
    puts record.inspect
  end
rescue Modelm::QueryExecutionError => e
  puts "Error executing query: #{e.message}"
  # Handle database execution errors
end
```

### Advanced Options

When using the service-class approach, you can provide additional options:

```ruby
# Specify a target model for execution (useful if you want ActiveRecord objects back)
# Note: This currently doesn't change the execution method but might in the future.
modelm_query = AskService.ask("Show me all products", model: Product)

# Specify a target table name for the LLM prompt
modelm_query = AskService.ask("Show me all items on sale", table_name: "products")
```

### The `Modelm::Query` Object

The `ask()` method returns an instance of `Modelm::Query`. This object has a few useful methods:

*   `raw_sql`: The raw SQL string generated by the LLM.
*   `sanitized_sql`: The SQL string after `sanitize!` has been called. Initially, it's the same as `raw_sql`.
*   `sanitize!(allow_only_select: true)`: Performs sanitization. By default, it ensures the query is a `SELECT` statement. Raises `Modelm::SanitizationError` on failure. Returns `self` for chaining.
*   `execute`: Executes the `sanitized_sql` against the database. 
    *   If the query originated from a model (e.g., `User.ask(...)`), it uses `YourModel.find_by_sql` and returns model instances.
    *   If the query originated from a service class (e.g., `AskService.ask(...)`), it uses `ActiveRecord::Base.connection.select_all` (for SELECT) or `execute` and returns an `ActiveRecord::Result` object (array of hashes) or connection-specific results.
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

