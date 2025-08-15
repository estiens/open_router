# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an enhanced fork of the OpenRouter Ruby gem that adds advanced AI application development features, including tool calling, structured outputs, and intelligent model selection. The gem maintains full backward compatibility while extending OpenRouter's API capabilities with Ruby-idiomatic DSLs and smart automation features.

## Architecture Overview

### Core Module Structure
```
OpenRouter (main module)
├── Configuration - Global gem configuration
├── Client - Main API client with enhanced features  
├── HTTP - Low-level HTTP communication module
├── Tool/ToolCall - Tool calling implementation
├── Schema - JSON Schema definitions for structured outputs
├── ModelRegistry - Model data management and caching
├── ModelSelector - Intelligent model selection with fluent DSL
└── Response - Enhanced response wrapper
```

### Key Design Patterns

**Modular Enhancement**: New features (Tool, ToolCall, Schema, Response, ModelRegistry, ModelSelector) are separate classes that integrate with the existing Client without breaking changes.

**DSL-Based Configuration**: Tools, schemas, and model selection use Ruby DSL builders for intuitive definition:
- `OpenRouter::Tool.define` for function calling tools
- `OpenRouter::Schema.define` for JSON schema validation
- `OpenRouter::ModelSelector.new` for intelligent model selection with chaining

**Response Wrapping**: The Response class wraps raw API responses, providing backward compatibility through delegation while adding new capabilities like `tool_calls` and `structured_output`.

**Smart Model Management**: ModelRegistry provides caching and capability detection for OpenRouter models, while ModelSelector offers fluent interface for requirement-based selection.

**Error Hierarchy**: Specific error classes inherit from `OpenRouter::Error`:
- `ToolCallError` for tool execution issues
- `SchemaValidationError` for schema violations  
- `StructuredOutputError` for JSON parsing failures
- `ModelRegistryError` for model data fetching/caching issues
- `ModelSelectionError` for model selection failures

### Module Loading Order
The main module defines base error classes first, then requires other modules to prevent circular dependencies. Tool and schema classes can reference `OpenRouter::Error` safely.

## Common Development Commands

### Testing
```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/tool_spec.rb

# Run with documentation format
bundle exec rspec --format documentation

# Run default task (tests + linting)
bundle exec rake
```

### Linting and Code Quality
```bash
# Run RuboCop
bundle exec rubocop

# Auto-correct RuboCop offenses
bundle exec rubocop -a

# Run Sorbet type checking (if configured)
bundle exec sorbet tc
```

### Development Setup
```bash
# Install dependencies
bundle install

# Interactive console for testing
bundle exec pry -I lib -r open_router
```

### Example Testing
```bash
# Test tool calling functionality
ruby -I lib examples/tool_calling_example.rb

# Test structured outputs
ruby -I lib examples/structured_outputs_example.rb
```

## Testing Strategy

### Test Organization
- Unit tests for individual classes (`tool_spec.rb`, `schema_spec.rb`, etc.)
- Integration tests for client functionality (`client_integration_spec.rb`)
- Response parsing tests (`response_spec.rb`)

### Mock vs Real API Testing
Tests use mocked responses by default. Real API calls are commented out in examples and integration tests to avoid requiring API keys during development.

### VCR Integration
The codebase is prepared for VCR (Video Cassette Recorder) integration for recording real API interactions, though specific cassettes aren't currently configured.

## Key Implementation Details

### Tool Calling Flow
1. Define tools using DSL or hash format with `OpenRouter::Tool.define`
2. Client serializes tools to OpenRouter API format
3. Response parses tool_calls and creates ToolCall objects
4. ToolCall provides methods for execution and conversation continuation

### Structured Outputs Flow  
1. Define schemas using DSL with validation rules via `OpenRouter::Schema.define`
2. Client serializes response_format parameter
3. Response automatically parses JSON content when schema is provided
4. Optional validation using json-schema gem (external dependency)

### Model Selection Flow
1. Create ModelSelector instance with fluent DSL for requirements specification
2. ModelRegistry fetches and caches model data from OpenRouter API on first use
3. ModelSelector filters models by capabilities, cost, context, and provider preferences
4. Returns optimal model(s) based on specified optimization strategy

### Backward Compatibility
The Response class delegates hash methods (`[]`, `dig`, `key?`) to the raw response, ensuring existing code using hash access patterns continues to work unchanged.

## Dependencies and Optional Features

### Core Dependencies
- `faraday` and `faraday-multipart` for HTTP communication
- `activesupport` for hash utilities and core extensions

### Optional Dependencies
- `json-schema` gem enables schema validation (graceful degradation if not present)

### Development Dependencies
- RSpec for testing
- RuboCop for linting  
- Sorbet for type checking
- Pry for debugging

## Environment Configuration

### Required Environment Variables
- `OPENROUTER_API_KEY` or `ACCESS_TOKEN` for API access

### Configuration Options
The gem supports both global configuration and per-client configuration:
```ruby
OpenRouter.configure do |config|
  config.access_token = ENV["OPENROUTER_API_KEY"]
  config.site_name = "Your App Name"
  config.site_url = "https://yourapp.com"
end
```

## MVP Scope and Limitations

### Not Yet Implemented (Post-MVP)
- **Streaming Responses**: The current implementation focuses on synchronous completions only. Streaming support is planned for a future release.
- **WebSocket Connections**: Real-time streaming will be added after the core features are stable.
- **Partial Response Handling**: All responses are currently processed as complete messages.

### Focus Areas for MVP
- Synchronous API calls with complete responses
- Tool calling with retry logic for failed executions
- Structured outputs with self-healing for non-native models
- Intelligent model selection based on requirements
- VCR-based testing for real API interactions

## CI/CD Configuration

The project uses GitHub Actions with Ruby 3.2.2+ support. The default rake task runs both tests and linting, ensuring code quality on every commit.