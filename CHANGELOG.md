# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-03-26

### Added
- **Adapter Pattern**: Pluggable LLM provider architecture via `AsktiveRecord::Adapters::Base`
  - Built-in `Adapters::OpenAI` adapter wrapping the ruby-openai gem
  - Custom adapters can be passed via `config.adapter = MyAdapter.new(...)`
- **SQL Sanitizer** (`AsktiveRecord::SqlSanitizer`): Defense-in-depth SQL injection prevention
  - Dangerous keyword blocklist (INSERT, UPDATE, DELETE, DROP, ALTER, etc.)
  - Injection pattern detection (UNION SELECT, semicolons, comments, SLEEP, etc.)
- **Prompt Injection Prevention**: Input escaping and pattern filtering in `AsktiveRecord::Prompt`
  - 2,000-character input limit
  - Detects and rejects common prompt injection patterns
- **Configurable Logger** (`AsktiveRecord::Log`): Structured logging with `[AsktiveRecord]` prefix
  - Replaces all `puts` calls with proper log levels (info, debug, warn, error)
  - Defaults to `Rails.logger` when available, falls back to `Logger.new($stdout)`
- **Schema Loader Module** (`AsktiveRecord::SchemaLoader`): Shared schema loading logic
- New configuration options: `temperature`, `max_tokens`, `cache_enabled`, `adapter`, `read_only`
- Comprehensive test suite: **180 examples** (up from 87), **96.63% line / 84.88% branch coverage**
  - Adapter specs (Base + OpenAI)
  - SqlSanitizer spec (31 examples)
  - Prompt spec (14 examples)
  - Log spec (7 examples)
  - SchemaLoader spec (10 examples)

### Changed
- **BREAKING**: Minimum Ruby version raised to 3.1.0 (was 3.0.0)
- **BREAKING**: Minimum Rails version raised to 7.0 (was 6.1)
- Default LLM model changed from `gpt-3.5-turbo` to `gpt-4o-mini` (3.5 is deprecated)
- `LlmService` now delegates to adapter instead of directly using `OpenAI::Client`
- `Query` class uses `SqlSanitizer` for robust validation
- Initializer template uses `ENV["OPENAI_API_KEY"]` instead of hardcoded placeholder
- Removed `zeitwerk` dependency (not needed for gem autoloading)
- Added `rubygems_mfa_required` metadata for publish security

### Fixed
- SQL injection vulnerability: queries were not validated before execution
- Prompt injection vulnerability: user input was passed directly to LLM prompts
- Removed `system()` shell execution call in Model module
- Fixed dead code paths in Query class (`extract_count_if_present`, no-op `exec_query`)
- API key no longer leaked in hardcoded initializer template

### Security
- All 8 identified security vulnerabilities have been addressed
- Defense-in-depth: SQL validation at LlmService, Query, and SqlSanitizer levels
- Read-only mode enabled by default (only SELECT queries allowed)

## [0.1.0] - 2025-05-13

- Initial release
