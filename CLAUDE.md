# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an enhanced fork of the OpenRouter Ruby gem that adds advanced AI application development features, including tool calling, structured outputs, intelligent model selection, and automatic response healing. The gem maintains full backward compatibility while extending OpenRouter's API capabilities with Ruby-idiomatic DSLs and smart automation features.

The project has evolved significantly from the original OpenRouter gem to include:
- Comprehensive tool calling support with validation
- Structured outputs with automatic healing for non-native models
- Intelligent model selection and fallback mechanisms
- Extensive VCR-based testing with real API interactions
- Response healing and self-correction capabilities
- Model registry with local caching and capability detection

## Architecture Overview

### Core Module Structure
```
OpenRouter (main module)
├── Configuration - Global gem configuration with healing and validation settings
├── Client - Main API client with enhanced features and capability validation
├── HTTP - Low-level HTTP communication module
├── Tool - Tool definition DSL and management
├── ToolCall - Individual tool call handling and validation
├── Schema - JSON Schema definitions for structured outputs with DSL
├── Response - Enhanced response wrapper with healing and structured output parsing
├── ModelRegistry - Model data management, caching, and capability detection
└── ModelSelector - Intelligent model selection with fluent DSL and fallback support
```

### Key Design Patterns

**Modular Enhancement**: New features are separate classes that integrate with the existing Client without breaking changes, enabling feature composition and backward compatibility.

**DSL-Based Configuration**: Tools, schemas, and model selection use Ruby DSL builders for intuitive definition:
- `OpenRouter::Tool.define` for function calling tools with parameter validation
- `OpenRouter::Schema.define` for JSON schema validation with type safety
- `OpenRouter::ModelSelector.new` for intelligent model selection with chaining

**Response Wrapping and Enhancement**: The Response class wraps raw API responses, providing:
- Backward compatibility through delegation 
- New capabilities like `tool_calls` and `structured_output`
- Automatic healing for malformed responses
- Validation and error reporting

**Smart Model Management**: 
- ModelRegistry provides caching, capability detection, and cost calculation
- ModelSelector offers fluent interface for requirement-based selection with fallbacks
- Automatic capability validation and warnings

**Self-Healing Architecture**: Automatic detection and correction of malformed responses:
- JSON healing for structured outputs from non-native models
- Configurable healing models and retry limits
- Graceful degradation when healing fails

**Error Hierarchy**: Comprehensive error handling with specific error classes:
- `ToolCallError` for tool execution issues
- `SchemaValidationError` for schema violations  
- `StructuredOutputError` for JSON parsing failures
- `ModelRegistryError` for model data fetching/caching issues
- `ModelSelectionError` for model selection failures
- `CapabilityError` for unsupported model features

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

# Test model selection
ruby -I lib examples/model_selection_example.rb

# Test smart completion (combines multiple features)
ruby -I lib examples/smart_completion_example.rb
```

## Testing Strategy

### Test Organization
- **Unit Tests**: Individual class testing (`tool_spec.rb`, `schema_spec.rb`, `model_selector_spec.rb`, etc.)
- **Integration Tests**: Client functionality and cross-module interactions
- **VCR Tests**: Real API interactions recorded and replayed for reliability
- **Performance Tests**: Response time and resource usage validation  
- **Contract Tests**: API contract validation and backward compatibility
- **Healing Tests**: Response healing functionality and edge cases

### Test Types by Category
- **Mocked Tests**: Fast unit tests with stubbed responses (default for CI)
- **VCR Tests**: Real API interactions recorded for integration testing
- **Property-Based Tests**: Randomized input testing for edge case discovery
- **Mutation Tests**: Code coverage quality validation
- **Debug Tests**: Specific issue reproduction and debugging

### VCR Integration Strategy
The codebase includes comprehensive VCR (Video Cassette Recorder) integration covering:
- All enhanced features (tools, structured outputs, model selection)
- Error handling scenarios (authentication, rate limiting, model failures)
- Model fallback and healing workflows
- Cost calculation and generation stats
- Real API contract validation

## Key Implementation Details

### Tool Calling Flow
1. Define tools using DSL or hash format with `OpenRouter::Tool.define`
2. Client validates model capabilities and serializes tools to OpenRouter API format
3. Response parses tool_calls and creates ToolCall objects with validation
4. ToolCall provides methods for execution, validation, and conversation continuation

### Structured Outputs Flow  
1. Define schemas using DSL with validation rules via `OpenRouter::Schema.define`
2. Client detects model capabilities and chooses native vs. forced extraction mode
3. For native support: Client sends response_format parameter to API
4. For forced mode: Client injects schema instructions into messages
5. Response automatically parses JSON content and applies healing if needed
6. Optional validation using json-schema gem with detailed error reporting

### Response Healing Flow
1. Response attempts to parse JSON from model output
2. If parsing fails and healing is enabled, invokes healer model
3. Healer model receives original schema and malformed response
4. Attempts to fix JSON while preserving semantic content
5. Falls back gracefully if healing fails after max attempts
6. Logs healing attempts and success/failure for monitoring

### Model Selection Flow
1. Create ModelSelector instance with fluent DSL for requirements specification
2. ModelRegistry fetches and caches model data from OpenRouter API on first use
3. ModelSelector filters models by capabilities, cost, context, and provider preferences
4. Returns optimal model(s) based on specified optimization strategy
5. Supports fallback chains and graceful degradation when requirements can't be met

### Model Fallback Flow
1. Client accepts array of models for fallback routing
2. OpenRouter API tries models in order until one succeeds
3. Client integrates fallbacks with tools, structured outputs, and model selection
4. Provides seamless failover without code changes

### Backward Compatibility
The Response class delegates hash methods (`[]`, `dig`, `key?`) to the raw response, ensuring existing code using hash access patterns continues to work unchanged. All new features are additive and optional.

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

## Current Development Status

### Implemented Features (v0.3.3)
- **Tool Calling**: Complete implementation with DSL, validation, and conversation handling
- **Structured Outputs**: Native and forced modes with automatic healing
- **Model Selection**: Intelligent selection with fallbacks and cost optimization
- **Model Registry**: Local caching with capability detection and cost calculation
- **Response Healing**: Automatic correction of malformed JSON responses
- **Model Fallbacks**: Array-based fallback routing with seamless integration
- **VCR Testing**: Comprehensive real API testing coverage
- **Backward Compatibility**: Full compatibility with existing OpenRouter gem usage

### Future Enhancements (Post-v1.0)
- **Streaming Responses**: Real-time streaming with tool calling support
- **WebSocket Connections**: Persistent connections for chat applications
- **Advanced Caching**: Response caching with TTL and invalidation strategies
- **Metrics & Monitoring**: Built-in usage tracking and performance monitoring
- **Plugin Architecture**: Extensible plugin system for custom functionality

### Development Priorities
1. **Stability**: Ensure all current features are robust and well-tested
2. **Performance**: Optimize response times and memory usage
3. **Documentation**: Maintain comprehensive documentation and examples
4. **Community**: Support community contributions and feedback
5. **Standards**: Follow Ruby and OpenRouter API best practices

## Development Workflow

### Feature Development Process
1. **Requirements**: Define clear requirements and acceptance criteria
2. **Design**: Plan implementation approach and API design
3. **TDD**: Write failing tests first (unit tests + VCR integration tests)
4. **Implementation**: Implement feature with comprehensive error handling
5. **Documentation**: Update documentation and examples
6. **Review**: Code review focusing on design patterns and edge cases
7. **Testing**: Comprehensive testing including edge cases and error scenarios

### Code Quality Standards
- **Ruby Style**: Follow RuboCop guidelines for consistent code style
- **Test Coverage**: Maintain high test coverage (>90%) with meaningful tests
- **Documentation**: Comprehensive documentation for all public APIs
- **Error Handling**: Graceful error handling with specific error types
- **Performance**: Consider performance implications of new features
- **Backward Compatibility**: Ensure all changes are backward compatible

### Release Process
1. **Version Bump**: Update version following semantic versioning
2. **Changelog**: Update CHANGELOG.md with detailed changes
3. **Testing**: Full test suite including VCR tests with fresh recordings
4. **Documentation**: Ensure documentation is up to date
5. **Examples**: Verify all examples work with new version
6. **Release**: Tag release and publish gem

## VCR Testing (Real API Integration)

The project includes comprehensive VCR tests that interact with the real OpenRouter API to ensure end-to-end functionality. These tests record actual API responses and replay them in subsequent runs.

### Setting Up VCR Tests

1. **Environment Variables**: Set your OpenRouter API key:
   ```bash
   export OPENROUTER_API_KEY="your_actual_api_key_here"
   ```

2. **VCR Configuration**: Located in `spec/support/vcr.rb` with automatic API key filtering.

3. **Cassette Storage**: Recordings stored in `spec/fixtures/vcr_cassettes/`

### Running VCR Tests

```bash
# Run all VCR tests (requires API key)
bundle exec rspec spec/vcr/

# Run specific VCR test suites
bundle exec rspec spec/vcr/basic_completion_spec.rb
bundle exec rspec spec/vcr/tool_calling_spec.rb
bundle exec rspec spec/vcr/structured_outputs_spec.rb
bundle exec rspec spec/vcr/model_registry_spec.rb
bundle exec rspec spec/vcr/model_fallback_spec.rb
bundle exec rspec spec/vcr/error_handling_spec.rb

# Run with documentation format for detailed output
bundle exec rspec spec/vcr/ --format documentation
```

### VCR Test Suites

#### 1. Basic Completions (`basic_completion_spec.rb`)
- Simple chat completions with various models
- Parameter validation (max_tokens, temperature, etc.)
- Multi-turn conversations
- System message handling
- Provider preferences and transforms
- Response metadata validation
- Backward compatibility verification

#### 2. Model Registry (`model_registry_spec.rb`)
- Real API model fetching from `/models` endpoint
- Cache management and refresh behavior
- Model processing and capability extraction
- Model lookup and cost calculation methods
- Error handling for network failures
- Integration with Client operations

#### 3. Tool Calling (`tool_calling_spec.rb`)
- Complete tool call workflows (DSL and hash-based tools)
- Single and multiple tool calls
- Tool choice parameters (auto, required, none, specific)
- Tool execution and conversation continuation
- Complex parameter types (objects, arrays)
- Error handling and validation
- Response structure verification

#### 4. Structured Outputs (`structured_outputs_spec.rb`)
- Native JSON schema-based structured outputs
- Simple and complex nested schemas
- Array of objects patterns
- Schema validation (when json-schema gem available)
- DSL vs hash-based schema definitions
- Error handling for malformed responses
- Multi-model compatibility testing

#### 5. Model Fallback (`model_fallback_spec.rb`)
- Model arrays with fallback routing
- Ordered preference handling
- Integration with providers, tools, and structured outputs
- Smart completion with fallback strategies
- Mixed model family fallbacks
- Performance characteristics
- Conversation continuation with fallbacks

#### 6. Error Handling (`error_handling_spec.rb`)
- Authentication errors (invalid/missing API keys)
- Model errors (non-existent, access restricted)
- Parameter validation failures
- Tool and schema definition errors
- Rate limiting scenarios
- Network timeouts and connectivity issues
- Error message quality validation

### VCR Best Practices

1. **API Key Security**: Keys are automatically filtered from recordings
2. **Cassette Management**: Use descriptive cassette names for easy identification
3. **Deterministic Tests**: Tests should be repeatable and not depend on external state
4. **Error Scenarios**: Include both success and failure cases in recordings
5. **Model Availability**: Some models may not be available in all accounts

### Refreshing VCR Cassettes

To record new API interactions:

```bash
# Delete existing cassettes to force re-recording
rm -rf spec/fixtures/vcr_cassettes/

# Run tests to generate new cassettes
bundle exec rspec spec/vcr/
```

### Environment-Specific Notes

- **CI/CD**: VCR tests should use pre-recorded cassettes in CI
- **Development**: Can re-record cassettes with real API calls
- **API Changes**: Cassettes may need refreshing when OpenRouter API evolves

## CI/CD Configuration

The project uses GitHub Actions with Ruby 3.2.2+ support. The default rake task runs both tests and linting, ensuring code quality on every commit.