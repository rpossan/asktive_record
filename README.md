# AsktiveRecord: A Ruby gem that lets your data answer like a human

[![Gem Version](https://badge.fury.io/rb/asktive_record.svg)](https://badge.fury.io/rb/asktive_record) <!-- Placeholder: Update once published -->
[![Build Status](https://github.com/rpossan/asktive_record/actions/workflows/main.yml/badge.svg)](https://github.com/rpossan/asktive_record/actions/workflows/main.yml) <!-- Placeholder: Update with correct repo path -->

> **AsktiveRecord** is a Ruby gem designed to bridge the gap between human language and database queries. It lets you interact with your Rails database as if you were having a conversation with a knowledgeable assistant. Instead of writing SQL or chaining ActiveRecord methods, you simply ask questions in plain English—like (or any language) "Who are my newest users?" or "What products sold the most last month?"—and get clear, human-friendly answers. AsktiveRecord translates your questions into database queries using LLM behind the scenes, so you can focus on what you want to know, not how to write the query.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'asktive_record'
```

And then execute:

```bash
$ bundle install
```

## Getting Started


Create configuration file:

```bash
$ bundle exec rails generate asktive_record:install
# It will create a new Rails initializer file at `config/initializers/asktive_record.rb`
```

Check the config/initializers/asktive_record.rb file to configure your LLM provider and API key. By default, setup will generate and read the `db/schema.rb` (or `db/structure.sql`) to make the LLM aware of your database structure.


```bash
$ bundle exec rails generate asktive_record:setup
```

This command will generate and read the `db/schema.rb` (or `db/structure.sql`) and make the LLM aware of your database structure. You can change the schema file path and skip the dump schema setting in the `config/initializers/asktive_record.rb` file if you are using a custom schema file or a non-standard schema location for legacy databases e.g., `db/custom_schema.pdf`.

See the [Configuration](#configuration) section for more details.

```ruby
# Include AsktiveRecord in your ApplicationRecord or specific models
class User < ApplicationRecord
  include AsktiveRecord
end

# Now you can query any table through this service
query = User.ask("Show me the last five users who signed up")
# => Returns a Query object with SQL targeting the users table based on your schema. Does not execute the SQL yet.

# You can check the object with the generated SQL:
query.raw_sql
# => "SELECT * FROM users ORDER BY created_at DESC LIMIT 5;"

# Call the execute method to run the query on the database
results = query.execute
# => Returns an array of User objects (if the query is a SELECT) or raises an `AsktiveRecord::QueryExecutionError` if the query fails.

# If you want to execute the query and get the response like human use the method answer
results = query.answer
# => Returns a string with the answer to the question, e.g., "The last five users who signed up are: [User1, User2, User3, User4, User5]"
```

For more detailed usage instructions, see the [Usage](#usage) section below.


## Features

*   **Natural Language to SQL**: Convert human-readable questions into SQL queries.
*   **LLM Integration**: Currently supports OpenAI's ChatGPT, with a design that allows for future expansion to other LLMs (e.g., Gemini).
*   **Get Answers, Not Just Data**: Use the `.answer` method to get concise, human-readable responses to your queries, rather than raw data or SQL.
*   **Avoid ActiveRecord Chaining and SQL**: No need to write complex ActiveRecord queries or SQL statements. Just ask your question in natural language.
*   **Works with Multiple Languages**: While the gem is designed with English in mind, it can handle queries in other languages, depending on the LLM's capabilities.
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
4.  **LLM Magic**: AsktiveRecord sends your query and the relevant schema context to the configured LLM.
5.  **SQL Generation**: The LLM returns a SQL query.
6.  **Safety First**: The `ask` method returns a `AsktiveRecord::Query` object containing the raw SQL. You can then inspect this SQL, apply sanitization rules (e.g., ensure it's only a `SELECT` statement), and then explicitly execute it.
7.  **Execution**: The `execute` method intelligently runs the sanitized SQL. If the query originated from a model (like `User.ask`), it uses `User.find_by_sql`. If it originated from a service class (like `AskService.ask`), it uses the general `ActiveRecord::Base.connection` to execute the query, returning an array of hashes for `SELECT` statements.

## Configuration


After installing the gem, you need to run the installer to generate the configuration file:

```bash
$ bundle exec rails generate asktive_record:install
```

This will create an initializer file at `config/initializers/asktive_record.rb`.

### Configure AsktiveRecord

Open `config/initializers/asktive_record.rb` and configure your LLM provider and API key:

```ruby
AsktiveRecord.configure do |config|
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
  # This is used by the `asktive_record:setup` command and the `.ask` method to provide context to the LLM.
  # Default is "db/schema.rb".
  # config.db_schema_path = "db/schema.rb"

  # === Skip dump schema ===
  # If set to true, the schema will not be dumped when running the
  # `asktive_record:setup` command.
  # This is useful if you want to manage schema dumps manually
  # or if you are using a different schema management strategy.
  # config.skip_dump_schema = false
end
```

**Important**: Securely manage your API keys. Using environment variables (e.g., `ENV["OPENAI_API_KEY"]`) is highly recommended.

### Prepare Schema for LLM

Run the setup command to help AsktiveRecord understand your database structure. This command attempts to read your schema file (e.g., `db/schema.rb`).

```bash
$ bundle exec rails generate asktive_record:setup
```

If your app uses a custom schema file or a non-standard schema location, you can specify the path in your configuration. For example, if your schema is located at `db/custom_schema.rb`, update your initializer:

```ruby
AsktiveRecord.configure do |config|
  config.db_schema_path = "db/custom_schema.rb"
  config.skip_dump_schema = true # If your app uses a legacy schema or doesn't need to dump it using rails db:schema:dump (default is false)
end
```

This ensures AsktiveRecord reads the correct schema file when providing context to the LLM. Make sure the specified file accurately reflects your database structure.


This step ensures that the LLM has the necessary context about your tables and columns to generate accurate SQL queries. The schema content is passed with each query to the LLM in the current version.

## Usage

AsktiveRecord offers two ways to query your database using natural language:

### 1. Model-Specific Querying

This approach ties queries to specific models, ideal when you know which table you want to query.
If you want to apply AsktiveRecord for all your Rails models, add the `include AsktiveRecord` line in your `ApplicationRecord` or specific models. This allows you to use the `.ask` method directly on those models.

```ruby
# First, include AsktiveRecord in your ApplicationRecord or specific models
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
  include AsktiveRecord
end

# Or in a specific model
# In this case, you can query the User model directly for the model table. All queries will be scoped to the users table.
class User < ApplicationRecord
  include AsktiveRecord
end

# Now you can query the User model directly
query = User.ask("Show me the last five users who signed up")
# => Returns a Query object with SQL targeting the users table, not the sql executed yet

# Call the execute method to run the query on the database
results = query.execute
# => Returns an array of User objects (if the query is a SELECT) or raises an

# If you want to execute the query and get the response like human use the method answer
results = query.answer
# => Returns a string with the answer to the question, e.g., "The last five users who signed up are: [User1, User2, User3, User4, User5]"
```

### 2. Service-Class Querying (Any Table)

This approach allows querying any table or multiple tables with joins, ideal for more complex queries or when you want a central service to handle all natural language queries.

```ruby
# Create a service class that includes AsktiveRecord
class AskService
  include AsktiveRecord
  # No additional code needed!
end

# Now you can query any table through this service
asktive_record_query = AskService.ask("Which is the last user created?")
# => Returns a Query object with SQL targeting the users table, not the sql executed yet

asktive_record_query = AskService.ask("Which is the cheapest product?").execute
# => Returns an ActiveRecord::Result object (array of hashes) with the cheapest product details

asktive_record_query = AskService.ask("Show me products with their categories").answer
# => Returns a Query object with SQL that might include JOINs between products and categories
# => Returns a string with the answer to the question, e.g., "The products with their categories are: [Product1, Product2, ...]"
```

### Working with Query Results

Once you have executed a query, you can work with the results. The `execute` method returns different types of results based on the context:
*   If the query is from a model (e.g., `User.ask(...)`), it returns an array of model instances (e.g., `User` objects).
*   If the query is from a service class (e.g., `AskService.ask(...)`), it returns an `ActiveRecord::Result` object, which is an array of hashes representing the query results.
```ruby
# Example of working with results from a model query
query = User.ask("Who are my newest users?")
results = query.execute
# => results is an array of User objects
```

### The `.answer` Method

The `.answer` method provides a human-friendly, natural language response to your query, instead of returning raw data or SQL. When you call `.answer` on a query object, AsktiveRecord executes the query and uses the LLM to generate a concise, readable answer based on the results.

### Example Usage


```ruby
# Using a service class to ask a question
response = AskService.ask("Which is the cheapest product?").answer
# => "The cheapest product is the Earphone."

# Using a model to ask a question
response = User.ask("Who signed up most recently?").answer
# => "The most recently signed up user is Alice Smith."

# Asking for a summary
response = AskService.ask("How many orders were placed last week?").answer
# => "There were 42 orders placed last week."
```

Tip: You can get the query param and interpolates it into the ask method to get a more specific answer. For example, if you want to know the last user created, you can do:

```ruby
customer = Customer.find(params[:id])
query = "Which is my most sold product?"
response = AskService.ask("For the customer #{customer.id}, #{query}").answer
# => "The most sold product for customer ABC is the Premium Widget."
```

The `.answer` method is ideal when you want a direct, human-readable summary, rather than an array of records or a SQL query.

The `ask()` method returns an instance of `AsktiveRecord::Query`. This object has a few useful methods:

*   `raw_sql`: The raw SQL string generated by the LLM.
*   `sanitized_sql`: The SQL string after `sanitize!` has been called. Initially, it's the same as `raw_sql`.
*   `sanitize!(allow_only_select: true)`: Performs sanitization. By default, it ensures the query is a `SELECT` statement. Raises `AsktiveRecord::SanitizationError` on failure. Returns `self` for chaining.
*   `execute`: Executes the `sanitized_sql` against the database.
    *   If the query originated from a model (e.g., `User.ask(...)`), it uses `YourModel.find_by_sql` and returns model instances.
    *   If the query originated from a service class (e.g., `AskService.ask(...)`), it uses `ActiveRecord::Base.connection.select_all` (for SELECT) or `execute` and returns an `ActiveRecord::Result` object (array of hashes) or connection-specific results.
*   `to_s`: Returns the `sanitized_sql` (or `raw_sql` if `sanitized_sql` hasn't been modified from raw).

## Logging
AsktiveRecord provides logging to help you debug and monitor natural language queries, generated SQL, and results. By default, logs are sent to the Rails logger at the `:info` level.

### Example Log Output

When you run a query, you might see logs like:

```
[AsktiveRecord] Received question: "Who are my newest users?"
[AsktiveRecord] Generated SQL: SELECT * FROM users ORDER BY created_at DESC LIMIT 5;
[AsktiveRecord] Sanitized SQL: SELECT * FROM users ORDER BY created_at DESC LIMIT 5;
[AsktiveRecord] Executing SQL via User.find_by_sql
[AsktiveRecord] Query results: [#<User id: 1, name: "Alice", ...>, ...]
```

When using the `.answer` method:

```
[AsktiveRecord] Received question: "How many orders were placed last week?"
[AsktiveRecord] Generated SQL: SELECT COUNT(*) FROM orders WHERE created_at >= '2024-06-01' AND created_at < '2024-06-08';
[AsktiveRecord] Query results: [{"count"=>42}]
[AsktiveRecord] LLM answer: "There were 42 orders placed last week."
```


## Supported LLMs

*   **Currently**: OpenAI (ChatGPT models like `gpt-3.5-turbo`, `gpt-4`).
*   **Future**: The gem is designed to be extensible. Support for other LLMs (like Google's Gemini) can be added by creating new LLM service adapters.

## Contributing

Contributions are welcome! Whether it's bug reports, feature requests, documentation improvements, or code contributions, please feel free to open an issue or submit a pull request on GitHub.

1.  Fork the repository ([https://github.com/rpossan/asktive_record/fork](https://github.com/rpossan/asktive_record/fork)).
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

Everyone interacting in the AsktiveRecord project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

---


