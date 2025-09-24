## [Unreleased]

### Added
- **Prompt Templates**: Reusable prompt templates with variable interpolation and few-shot learning support
- **Streaming Client**: Enhanced streaming client with comprehensive callback system and response reconstruction
- **Usage Tracking**: Comprehensive token usage and cost tracking with performance analytics
- **Response Analytics**: Detailed response metadata including tokens, costs, cache hits, and performance metrics
- **Callback System**: Extensible event system for monitoring requests, responses, tools, and errors
- **Cost Management**: Built-in cost estimation and budget constraint features
- **Performance Optimization**: Batching, parallelization, and memory management utilities
- **Debug Mode**: Comprehensive debugging and troubleshooting utilities

### Changed
- **Enhanced Client**: Added comprehensive callback system with events for requests, responses, tools, and errors
- **Streaming Improvements**: Complete rewrite of streaming client with proper event handling and response accumulation
- **Response Object**: Extended with detailed analytics, cost information, and performance metrics
- **Documentation**: Massive documentation overhaul with comprehensive examples and troubleshooting guides
- **API Reference**: Complete API reference with all classes, methods, and configuration options

### Fixed
- **Streaming Edge Cases**: Fixed various edge cases in streaming response handling
- **Memory Management**: Improved memory usage for long-running applications
- **Error Reporting**: Enhanced error messages with better debugging information

## [0.3.3] - 2024-12-XX

### Added
- **Response Healing**: Automatic correction of malformed JSON responses from models without native structured output support
- **Model Fallbacks**: Support for model arrays with automatic failover routing
- **Enhanced Error Handling**: Comprehensive error hierarchy with specific error types
- **Capability Validation**: Automatic model capability checking with warnings
- **Cost Calculation**: Model cost estimation and budget constraints in ModelSelector
- **Performance Testing**: Additional test coverage for performance scenarios
- **Debug Healing**: Specialized testing for response healing edge cases

### Changed
- **Improved Model Selection**: Enhanced fallback logic and graceful degradation
- **Response Class**: Extended with healing capabilities and better error reporting
- **Configuration**: Added healing configuration options (auto_heal_responses, healer_model, max_heal_attempts)
- **VCR Testing**: Expanded VCR test coverage for all new features
- **Documentation**: Comprehensive updates to README, CLAUDE.md, and docs/ directory

### Fixed
- **Edge Cases**: Various edge case handling improvements in structured outputs
- **Error Reporting**: Better error messages and validation feedback
- **Memory Usage**: Optimized caching and model registry performance

## [0.3.2] - 2024-12-XX

### Added
- **Model Registry**: Local caching and querying of OpenRouter model data
- **Model Selector**: Intelligent model selection with fluent DSL
- **Structured Output Validation**: Optional JSON Schema validation
- **VCR Integration**: Comprehensive real API testing with VCR

### Changed
- **Enhanced Response Object**: Added structured_output parsing and validation
- **Client Enhancements**: Added capability validation and automatic model selection
- **Test Suite**: Expanded test coverage with VCR recordings

## [0.3.1] - 2024-12-XX

### Added
- **Tool Calling Support**: Complete OpenRouter function calling API support
- **Structured Outputs**: JSON Schema-based structured response format support
- **Ruby DSLs**: Intuitive DSLs for tool definitions and schema creation
- **Enhanced Response Handling**: Rich Response objects with tool call parsing

### Changed
- **Client API**: Extended complete() method with tools and response_format parameters
- **Response Processing**: Added automatic parsing for tool calls and structured outputs
- **Error Handling**: Added specific error classes for different failure types

## [0.3.0] - 2024-05-03

### Changed
- Uses Faraday's built-in JSON mode
- Added support for configuring Faraday and its middleware
- Spec creates a STDOUT logger by default (headers, bodies, errors)  
- Spec filters Bearer token from logs by default

## [0.1.0] - 2024-03-19

### Added
- Initial release of OpenRouter Ruby gem
- Basic chat completion support
- Model selection and routing
- OpenRouter API integration
