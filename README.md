# AsktiveRecord: A Ruby gem that lets your data answer like a human

[![Gem Version](https://badge.fury.io/rb/asktive_record.svg)](https://badge.fury.io/rb/asktive_record)
[![Build Status](https://github.com/rpossan/asktive_record/actions/workflows/main.yml/badge.svg)](https://github.com/rpossan/asktive_record/actions/workflows/main.yml)

> **AsktiveRecord** is a Ruby gem designed to bridge the gap between human language and database queries. It lets you interact with your Rails database as if you were having a conversation with a knowledgeable assistant. Instead of writing SQL or chaining ActiveRecord methods, you simply ask questions in plain English (or any language)—like "Who are my newest users?" or "What products sold the most last month?"—and get clear, human-friendly answers. AsktiveRecord translates your questions into database queries using LLMs behind the scenes, so you can focus on what you want to know, not how to write the query.

## Requirements

- Ruby >= 3.1.0
- Rails >= 7.0 (railties)
- An OpenAI API key (or a custom LLM adapter)

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

Check the `config/initializers/asktive_record.rb` file to configure your LLM provider and API key. By default, setup will generate and read the `db/schema.rb` (or `db/structure.sql`) to make the LLM aware of your database structure.

```bash
$ bundle exec rails generate asktive_record:setup
```

This command will generate and read the `db/schema.rb` (or `db/structure.sql`) and make the LLM aware of your database structure. You can change the schema file path and skip the dump schema setting in the `config/initializers/asktive_record.rb` file if you are using a custom schema file or a non-standard schema location for legacy databases.

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
# => "SELECT * FROM users ORDER BY created_at DESC LIMIT 5"

# Call the execute method to run the query on the database
results = query.execute
# => Returns an array of User objects (if the query is a SELECT) or raises an `AsktiveRecord::QueryExecutionError` if the query fails.

# If you want to execute the query and get the response like human use the method answer
results = query.answer
# => Returns a string with the answer to the question, e.g., "The last five users who signed up are: [User1, User2, User3, User4, User5]"
```

For more detailed usage instructions, see the [Usage](#usage) section below.

## Features

* **Natural Language to SQL**: Convert human-readable questions into SQL queries.
* **LLM Adapter Pattern**: Pluggable architecture supporting OpenAI out of the box, with an extensible base for custom adapters (Anthropic, Gemini, local models, etc.).
* **Security First**:
  * SQL injection prevention via `SqlSanitizer` (keyword blocklist + injection pattern detection)
  * Prompt injection prevention with input escaping and pattern filtering
  * Read-only mode by default (only SELECT queries allowed)
  * Defense-in-depth validation at multiple layers
* **Get Answers, Not Just Data**: Use the `.answer` method to get concise, human-readable responses to your queries, rather than raw data or SQL.
* **Avoid ActiveRecord Chaining and SQL**: No need to write complex ActiveRecord queries or SQL statements. Just ask your question in natural language.
* **Works with Multiple Languages**: While the gem is designed with English in mind, it can handle queries in other languages, depending on the LLM's capabilities.
* **Flexible Querying Options**:
  * Use with specific models (e.g., `User.ask("query")`)
  * Use with service classes to query any table (e.g., `AskService.ask("query")`)
* **Database Schema Awareness**: Passes your database schema to the LLM for context-aware query generation.
* **Developer Control**: Provides a two-step query process: first, get the LLM-generated SQL, then sanitize and execute it, giving you full control over what runs against your database.
* **Smart Execution**: Automatically uses the appropriate execution method (`find_by_sql` for models, `ActiveRecord::Base.connection` for service classes).
* **Structured Logging**: Configurable logging with `[AsktiveRecord]` prefix, defaults to `Rails.logger`.
* **Easy Setup**: Simple CLI commands to install and configure the gem in your Rails project.
* **Customizable Configuration**: Set your LLM provider, API keys, model preferences, temperature, and more through an initializer.

## How It Works

1. **Setup**: You install the gem and run a setup command. This command reads your `db/schema.rb` (or `db/structure.sql`) and makes the LLM aware of your database structure.
2. **Configuration**: You configure your LLM API key and preferences in an initializer file.
3. **Querying**: You can query your database in two ways:
   * Model-specific: `User.ask("your natural language query")`
   * Service-based (any table): `AskService.ask("your natural language query")`
4. **LLM Processing**: AsktiveRecord sends your query and the relevant schema context to the configured LLM via the adapter.
5. **SQL Generation**: The LLM returns a SQL query.
6. **Safety First**: The generated SQL is validated through multiple layers:
   * `SqlSanitizer` checks for dangerous keywords and injection patterns
   * Read-only mode ensures only SELECT statements execute
   * The `Query` object lets you inspect the SQL before execution
7. **Execution**: The `execute` method runs the sanitized SQL. If the query originated from a model (like `User.ask`), it uses `User.find_by_sql`. If from a service class (like `AskService.ask`), it uses `ActiveRecord::Base.connection`.

## Configuration

After installing the gem, run the installer to generate the configuration file:

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
  # config.llm_provider = :openai

  # === LLM API Key ===
  # Set your API key for the chosen LLM provider.
  # It is strongly recommended to use environment variables for sensitive data.
  config.llm_api_key = ENV["OPENAI_API_KEY"]

  # === LLM Model Name ===
  # Specify the model name. Default is "gpt-4o-mini".
  # Other models like "gpt-4o" or "gpt-4-turbo" can be used.
  # config.llm_model_name = "gpt-4o-mini"

  # === Database Schema Path ===
  # Path to your schema file (schema.rb or structure.sql).
  # Default is "db/schema.rb".
  # config.db_schema_path = "db/schema.rb"

  # === Skip dump schema ===
  # If true, the schema will not be dumped during `asktive_record:setup`.
  # config.skip_dump_schema = false

  # === Read-Only Mode ===
  # When true (default), only SELECT queries are allowed.
  # config.read_only = true

  # === LLM Temperature ===
  # Controls randomness. Lower = more deterministic. Default: 0.2
  # config.temperature = 0.2

  # === LLM Max Tokens ===
  # Maximum tokens in the LLM response. Default: 250
  # config.max_tokens = 250

  # === Custom Adapter ===
  # Provide a custom LLM adapter instead of using the built-in provider.
  # The adapter must inherit from AsktiveRecord::Adapters::Base.
  # config.adapter = MyCustomAdapter.new(api_key: ENV["MY_LLM_KEY"])

  # === Custom Logger ===
  # Set a custom logger. Defaults to Rails.logger when available.
  # config.logger = Logger.new($stdout)
end
```

**Important**: Securely manage your API keys. Using environment variables (e.g., `ENV["OPENAI_API_KEY"]`) is strongly recommended. Never commit API keys to source control.

### Custom LLM Adapters

AsktiveRecord uses an adapter pattern for LLM communication. You can create custom adapters for any LLM provider:

```ruby
class AnthropicAdapter < AsktiveRecord::Adapters::Base
  def chat(prompt, options = {})
    # Your Anthropic API call here
    # Must return a string response (the SQL or answer text)
  end

  def default_model_name
    "claude-sonnet-4-20250514"
  end
end

# Use it in your configuration:
AsktiveRecord.configure do |config|
  config.adapter = AnthropicAdapter.new(
    api_key: ENV["ANTHROPIC_API_KEY"],
    model_name: "claude-sonnet-4-20250514"
  )
end
```

### Prepare Schema for LLM

Run the setup command to help AsktiveRecord understand your database structure:

```bash
$ bundle exec rails generate asktive_record:setup
```

If your app uses a custom schema file or a non-standard schema location, you can specify the path in your configuration:

```ruby
AsktiveRecord.configure do |config|
  config.db_schema_path = "db/custom_schema.rb"
  config.skip_dump_schema = true
end
```

This ensures AsktiveRecord reads the correct schema file when providing context to the LLM.

## Usage

AsktiveRecord offers two ways to query your database using natural language:

### 1. Model-Specific Querying

This approach ties queries to specific models, ideal when you know which table you want to query.

```ruby
# Include AsktiveRecord in your ApplicationRecord or specific models
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
  include AsktiveRecord
end

# Or in a specific model
class User < ApplicationRecord
  include AsktiveRecord
end

# Now you can query the User model directly
query = User.ask("Show me the last five users who signed up")
# => Returns a Query object with SQL targeting the users table

# Call the execute method to run the query on the database
results = query.execute
# => Returns an array of User objects

# If you want a human-readable answer, use the answer method
results = query.answer
# => "The last five users who signed up are: Alice, Bob, Charlie, Diana, Eve."
```

### 2. Service-Class Querying (Any Table)

This approach allows querying any table or multiple tables with joins:

```ruby
# Create a service class that includes AsktiveRecord
class AskService
  include AsktiveRecord
  # No additional code needed!
end

# Query any table through this service
query = AskService.ask("Which is the last user created?")
# => Returns a Query object

results = AskService.ask("Which is the cheapest product?").execute
# => Returns an ActiveRecord::Result object (array of hashes)

answer = AskService.ask("Show me products with their categories").answer
# => "The products with their categories are: Widget (Electronics), Gadget (Electronics), ..."
```

### Working with Query Results

The `execute` method returns different types of results based on the context:
* **Model queries** (e.g., `User.ask(...)`): returns an array of model instances (e.g., `User` objects)
* **Service queries** (e.g., `AskService.ask(...)`): returns an `ActiveRecord::Result` object (array of hashes)

```ruby
# Example of working with results from a model query
query = User.ask("Who are my newest users?")
results = query.execute
# => results is an array of User objects
```

### The `.answer` Method

The `.answer` method provides a human-friendly, natural language response to your query. When you call `.answer`, AsktiveRecord executes the query and uses the LLM to generate a concise, readable answer based on the results.

### Example Usage

```ruby
# Using a service class
response = AskService.ask("Which is the cheapest product?").answer
# => "The cheapest product is the Earphone."

# Using a model
response = User.ask("Who signed up most recently?").answer
# => "The most recently signed up user is Alice Smith."

# Asking for a summary
response = AskService.ask("How many orders were placed last week?").answer
# => "There were 42 orders placed last week."
```

Tip: You can interpolate dynamic values into the question:

```ruby
customer = Customer.find(params[:id])
response = AskService.ask("For customer #{customer.id}, which is the most sold product?").answer
# => "The most sold product for customer ABC is the Premium Widget."
```

### Query Object API

The `ask()` method returns an instance of `AsktiveRecord::Query`. Key methods:

* `raw_sql` — The raw SQL string generated by the LLM.
* `sanitized_sql` — The SQL string after `sanitize!` has been called.
* `sanitize!(allow_only_select: true)` — Validates the query through `SqlSanitizer`. Raises `AsktiveRecord::SanitizationError` on failure.
* `execute` — Executes the sanitized SQL against the database.
* `answer` — Executes the query and returns a human-readable LLM-generated answer.
* `to_s` — Returns the sanitized SQL (or raw SQL if not yet sanitized).

## Logging

AsktiveRecord provides structured logging to help you debug and monitor queries. By default, logs are sent to `Rails.logger` with the `[AsktiveRecord]` prefix.

### Example Log Output

```
[AsktiveRecord] Received question: "Who are my newest users?"
[AsktiveRecord] Generated SQL: SELECT * FROM users ORDER BY created_at DESC LIMIT 5
[AsktiveRecord] Sanitized SQL: SELECT * FROM users ORDER BY created_at DESC LIMIT 5
```

When using `.answer`:

```
[AsktiveRecord] Received question: "How many orders were placed last week?"
[AsktiveRecord] Generated SQL: SELECT COUNT(*) FROM orders WHERE created_at >= '2024-06-01'
[AsktiveRecord] Answering question: How many orders were placed last week?
```

## Security

AsktiveRecord implements defense-in-depth security:

* **SQL Sanitization**: All generated SQL passes through `SqlSanitizer` which blocks dangerous keywords (INSERT, UPDATE, DELETE, DROP, ALTER, TRUNCATE, etc.) and injection patterns (UNION SELECT, semicolons, comments, SLEEP, etc.)
* **Read-Only Mode**: Enabled by default — only SELECT queries are allowed to execute
* **Prompt Injection Prevention**: User input is escaped and filtered before being sent to the LLM, with a 2,000-character limit
* **No Hardcoded Secrets**: Initializer template uses `ENV["OPENAI_API_KEY"]` by default
* **Multi-Layer Validation**: SQL is validated at the LLM response level, the Query level, and the SqlSanitizer level

## Supported LLMs

* **Built-in**: OpenAI (models like `gpt-4o-mini`, `gpt-4o`, `gpt-4-turbo`)
* **Custom Adapters**: Any LLM can be supported by creating an adapter that inherits from `AsktiveRecord::Adapters::Base` and implements the `#chat` method

## Contributing

Contributions are welcome! Whether it's bug reports, feature requests, documentation improvements, or code contributions, please feel free to open an issue or submit a pull request on GitHub.

1. Fork the repository ([https://github.com/rpossan/asktive_record/fork](https://github.com/rpossan/asktive_record/fork)).
2. Create your feature branch (`git checkout -b my-new-feature`).
3. Commit your changes (`git commit -am 'Add some feature'`).
4. Push to the branch (`git push origin my-new-feature`).
5. Create a new Pull Request.

Please make sure to add tests for your changes and ensure all tests pass (`bundle exec rspec`). Also, adhere to the existing code style (you can use RuboCop: `bundle exec rubocop`).

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bundle exec rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the AsktiveRecord project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
