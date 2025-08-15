# OpenRouter Enhanced - Ruby Gem

The future will bring us hundreds of language models and dozens of providers for each. How will you choose the best?

The [OpenRouter API](https://openrouter.ai/docs) is a single unified interface for all LLMs! And now you can easily use it with Ruby! 🤖🌌

**OpenRouter Enhanced** is an advanced fork of the [original OpenRouter Ruby gem](https://github.com/OlympiaAI/open_router) by [Obie Fernandez](https://github.com/obie) that adds comprehensive AI application development features including tool calling, structured outputs, intelligent model selection, and automatic response healing—all while maintaining full backward compatibility.

## Enhanced Features

This fork extends the original OpenRouter gem with enterprise-grade AI development capabilities:

- **Tool Calling**: Full support for OpenRouter's function calling API with Ruby-idiomatic DSL for tool definitions
- **Structured Outputs**: JSON Schema validation with automatic healing for non-native models and Ruby DSL for schema definitions  
- **Smart Model Selection**: Intelligent model selection with fluent DSL for cost optimization, capability requirements, and provider preferences
- **Model Registry**: Local caching and querying of OpenRouter model data with capability detection
- **Enhanced Response Handling**: Rich Response objects with automatic parsing for tool calls and structured outputs
- **Automatic Healing**: Self-healing responses for malformed JSON from models that don't natively support structured outputs
- **Model Fallbacks**: Automatic failover between models with graceful degradation
- **Comprehensive Testing**: VCR-based integration tests with real API interactions
- **Backward Compatible**: All existing code continues to work unchanged

### Core OpenRouter Benefits

- **Prioritize price or performance**: OpenRouter scouts for the lowest prices and best latencies/throughputs across dozens of providers, and lets you choose how to prioritize them.
- **Standardized API**: No need to change your code when switching between models or providers. You can even let users choose and pay for their own.
- **Easy integration**: This Ruby gem provides a simple and intuitive interface to interact with the OpenRouter API, making it effortless to integrate AI capabilities into your Ruby applications.

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Core Features](#core-features)
  - [Basic Completions](#basic-completions)
  - [Model Selection](#model-selection)
- [Enhanced Features](#enhanced-features)
  - [Tool Calling](#tool-calling)
  - [Structured Outputs](#structured-outputs)
  - [Smart Model Selection](#smart-model-selection)
  - [Model Registry](#model-registry)
- [Advanced Usage](#advanced-usage)
  - [Model Fallbacks](#model-fallbacks)
  - [Response Healing](#response-healing)
  - [Cost Management](#cost-management)
- [Testing](#testing)
- [API Reference](#api-reference)
- [Contributing](#contributing)
- [License](#license)

## Installation

### Bundler

Add this line to your application's Gemfile:

```ruby
gem "open_router_enhanced"
```

And then execute:

```bash
bundle install
```

### Gem install

Or install it directly:

```bash
gem install open_router_enhanced
```

And require it in your code:

```ruby
require "open_router"
```

## Quick Start

### 1. Get Your API Key
- Sign up at [OpenRouter](https://openrouter.ai)
- Get your API key from [https://openrouter.ai/keys](https://openrouter.ai/keys)

### 2. Basic Setup and Usage

```ruby
require "open_router"

# Configure the gem
OpenRouter.configure do |config|
  config.access_token = ENV["OPENROUTER_API_KEY"]
  config.site_name = "Your App Name"
  config.site_url = "https://yourapp.com"
end

# Create a client
client = OpenRouter::Client.new

# Basic completion
response = client.complete([
  { role: "user", content: "What is the capital of France?" }
])

puts response.content
# => "The capital of France is Paris."
```

### 3. Enhanced Features Quick Example

```ruby
# Smart model selection
model = OpenRouter::ModelSelector.new
                                 .require(:function_calling)
                                 .optimize_for(:cost)
                                 .choose

# Tool calling with structured output
weather_tool = OpenRouter::Tool.define do
  name "get_weather"
  description "Get current weather"
  parameters do
    string :location, required: true
  end
end

weather_schema = OpenRouter::Schema.define("weather") do
  string :location, required: true
  number :temperature, required: true
  string :conditions, required: true
end

response = client.complete(
  [{ role: "user", content: "What's the weather in Tokyo?" }],
  model: model,
  tools: [weather_tool],
  response_format: weather_schema
)

# Process results
if response.has_tool_calls?
  weather_data = response.structured_output
  puts "Temperature in #{weather_data['location']}: #{weather_data['temperature']}°"
end
```

## Configuration

### Global Configuration

Configure the gem globally, for example in an `open_router.rb` initializer file. Never hardcode secrets into your codebase - instead use `Rails.application.credentials` or something like [dotenv](https://github.com/motdotla/dotenv) to pass the keys safely into your environments.

```ruby
OpenRouter.configure do |config|
  config.access_token = ENV["OPENROUTER_API_KEY"]
  config.site_name = "Your App Name"
  config.site_url = "https://yourapp.com"
  
  # Optional: Configure response healing for non-native structured output models
  config.auto_heal_responses = true
  config.healer_model = "openai/gpt-4o-mini"
  config.max_heal_attempts = 2
  
  # Optional: Configure strict mode for capability validation
  config.strict_mode = true
  
  # Optional: Configure automatic forcing for unsupported models
  config.auto_force_on_unsupported_models = true
end
```

### Per-Client Configuration

You can also configure clients individually:

```ruby
client = OpenRouter::Client.new(
  access_token: ENV["OPENROUTER_API_KEY"],
  request_timeout: 120
)
```

### Faraday Configuration

The configuration object exposes a [`faraday`](https://github.com/lostisland/faraday-retry) method that you can pass a block to configure Faraday settings and middleware.

This example adds `faraday-retry` and a logger that redacts the api key so it doesn't get leaked to logs.

```ruby
require 'faraday/retry'

retry_options = {
  max: 2,
  interval: 0.05,
  interval_randomness: 0.5,
  backoff_factor: 2
}

OpenRouter::Client.new(access_token: ENV["ACCESS_TOKEN"]) do |config|
  config.faraday do |f|
    f.request :retry, retry_options
    f.response :logger, ::Logger.new($stdout), { headers: true, bodies: true, errors: true } do |logger|
      logger.filter(/(Bearer) (\S+)/, '\1[REDACTED]')
    end
  end
end
```

#### Change version or timeout

The default timeout for any request using this library is 120 seconds. You can change that by passing a number of seconds to the `request_timeout` when initializing the client.

```ruby
client = OpenRouter::Client.new(
    access_token: "access_token_goes_here",
    request_timeout: 240 # Optional
)
```

## Core Features

### Basic Completions

Hit the OpenRouter API for a completion:

```ruby
messages = [
  { role: "system", content: "You are a helpful assistant." },
  { role: "user", content: "What is the color of the sky?" }
]

response = client.complete(messages)
puts response.content
# => "The sky is typically blue during the day due to a phenomenon called Rayleigh scattering. Sunlight..."
```

### Model Selection

Pass an array to the `model` parameter to enable [explicit model routing](https://openrouter.ai/docs#model-routing).

```ruby
OpenRouter::Client.new.complete(
  [
    { role: "system", content: SYSTEM_PROMPT },
    { role: "user", content: "Provide analysis of the data formatted as JSON:" }
  ],
  model: [
    "mistralai/mixtral-8x7b-instruct:nitro",
    "mistralai/mixtral-8x7b-instruct"
  ],
  extras: {
    response_format: {
      type: "json_object"
    }
  }
)
```

[Browse full list of models available](https://openrouter.ai/models) or fetch from the OpenRouter API:

```ruby
models = client.models
puts models
# => [{"id"=>"openrouter/auto", "object"=>"model", "created"=>1684195200, "owned_by"=>"openrouter", "permission"=>[], "root"=>"openrouter", "parent"=>nil}, ...]
```

### Generation Stats

Query the generation stats for a given generation ID:

```ruby
generation_id = "generation-abcdefg"
stats = client.query_generation_stats(generation_id)
puts stats
# => {"id"=>"generation-abcdefg", "object"=>"generation", "created"=>1684195200, "model"=>"openrouter/auto", "usage"=>{"prompt_tokens"=>10, "completion_tokens"=>50, "total_tokens"=>60}, "cost"=>0.0006}
```

## Enhanced Features

### Tool Calling

Enable AI models to call functions and interact with external APIs using OpenRouter's function calling with an intuitive Ruby DSL.

#### Quick Example

```ruby
# Define a tool using the DSL
weather_tool = OpenRouter::Tool.define do
  name "get_weather"
  description "Get current weather for a location"
  
  parameters do
    string :location, required: true, description: "City name"
    string :units, enum: ["celsius", "fahrenheit"], default: "celsius"
  end
end

# Use in completion
response = client.complete(
  [{ role: "user", content: "What's the weather in London?" }],
  model: "anthropic/claude-3.5-sonnet",
  tools: [weather_tool],
  tool_choice: "auto"
)

# Handle tool calls
if response.has_tool_calls?
  response.tool_calls.each do |tool_call|
    result = fetch_weather(tool_call.arguments["location"], tool_call.arguments["units"])
    puts "Weather in #{tool_call.arguments['location']}: #{result}"
  end
end
```

#### Key Features

- **Ruby DSL**: Define tools with intuitive Ruby syntax
- **Parameter Validation**: Automatic validation against JSON Schema
- **Tool Choice Control**: Auto, required, none, or specific tool selection
- **Conversation Continuation**: Easy message building for multi-turn conversations
- **Error Handling**: Graceful error handling and validation

📖 **[Complete Tool Calling Documentation](docs/tools.md)**

### Structured Outputs

Get JSON responses that conform to specific schemas with automatic validation and healing for non-native models.

#### Quick Example

```ruby
# Define a schema using the DSL
user_schema = OpenRouter::Schema.define("user") do
  string :name, required: true, description: "Full name"
  integer :age, required: true, minimum: 0, maximum: 150
  string :email, required: true, description: "Email address"
  boolean :premium, description: "Premium account status"
end

# Get structured response
response = client.complete(
  [{ role: "user", content: "Create a user: John Doe, 30, john@example.com" }],
  model: "openai/gpt-4o",
  response_format: user_schema
)

# Access parsed JSON data
user = response.structured_output
puts user["name"]    # => "John Doe"
puts user["age"]     # => 30
puts user["email"]   # => "john@example.com"
```

#### Key Features

- **Ruby DSL**: Define JSON schemas with Ruby syntax
- **Automatic Healing**: Self-healing for models without native structured output support
- **Validation**: Optional validation with detailed error reporting
- **Complex Schemas**: Support for nested objects, arrays, and advanced constraints
- **Fallback Support**: Graceful degradation for unsupported models

📖 **[Complete Structured Outputs Documentation](docs/structured_outputs.md)**

### Smart Model Selection

Automatically choose the best AI model based on your specific requirements using a fluent DSL.

#### Quick Example

```ruby
# Find the cheapest model with function calling
model = OpenRouter::ModelSelector.new
                                 .require(:function_calling)
                                 .optimize_for(:cost)
                                 .choose

# Advanced selection with multiple criteria
model = OpenRouter::ModelSelector.new
                                 .require(:function_calling, :vision)
                                 .within_budget(max_cost: 0.01)
                                 .min_context(50_000)
                                 .prefer_providers("anthropic", "openai")
                                 .optimize_for(:performance)
                                 .choose

# Get multiple options with fallbacks
models = OpenRouter::ModelSelector.new
                                  .require(:structured_outputs)
                                  .choose_with_fallbacks(limit: 3)
# => ["openai/gpt-4o-mini", "anthropic/claude-3-haiku", "google/gemini-flash"]
```

#### Key Features

- **Fluent DSL**: Chain requirements and preferences intuitively
- **Cost Optimization**: Find models within budget constraints
- **Capability Matching**: Require specific features like function calling or vision
- **Provider Preferences**: Prefer or avoid specific providers
- **Graceful Fallbacks**: Automatic fallback with requirement relaxation
- **Performance Tiers**: Choose between cost and performance optimization

📖 **[Complete Model Selection Documentation](docs/model_selection.md)**

### Model Registry

Access detailed information about available models and their capabilities.

#### Quick Example

```ruby
# Get specific model information
model_info = OpenRouter::ModelRegistry.get_model_info("anthropic/claude-3-5-sonnet")
puts model_info[:capabilities]  # [:chat, :function_calling, :structured_outputs, :vision]
puts model_info[:cost_per_1k_tokens]  # { input: 0.003, output: 0.015 }

# Find models matching requirements
candidates = OpenRouter::ModelRegistry.models_meeting_requirements(
  capabilities: [:function_calling],
  max_input_cost: 0.01
)

# Estimate costs for specific usage
cost = OpenRouter::ModelRegistry.calculate_estimated_cost(
  "openai/gpt-4o",
  input_tokens: 1000,
  output_tokens: 500
)
puts "Estimated cost: $#{cost.round(4)}"  # => "Estimated cost: $0.0105"
```

#### Key Features

- **Model Discovery**: Browse all available models and their specifications
- **Capability Detection**: Check which features each model supports
- **Cost Calculation**: Estimate costs for specific token usage
- **Local Caching**: Fast model data access with automatic cache management
- **Real-time Updates**: Refresh model data from OpenRouter API

## Advanced Usage

### Model Fallbacks

Use multiple models with automatic failover for increased reliability.

```ruby
# Define fallback chain
response = client.complete(
  messages,
  model: ["openai/gpt-4o", "anthropic/claude-3-5-sonnet", "anthropic/claude-3-haiku"],
  tools: tools
)

# Or use ModelSelector for intelligent fallbacks
models = OpenRouter::ModelSelector.new
                                  .require(:function_calling)
                                  .choose_with_fallbacks(limit: 3)

response = client.complete(messages, model: models, tools: tools)
```

### Response Healing

Automatically heal malformed responses from models that don't natively support structured outputs.

```ruby
# Configure global healing
OpenRouter.configure do |config|
  config.auto_heal_responses = true
  config.healer_model = "openai/gpt-4o-mini"
  config.max_heal_attempts = 2
end

# The gem automatically heals malformed JSON responses
response = client.complete(
  messages,
  model: "some/model-without-native-structured-outputs",
  response_format: schema  # Will be automatically healed if malformed
)
```

### Cost Management

Track and manage AI model costs effectively.

```ruby
# Estimate costs before making requests
cost = OpenRouter::ModelRegistry.calculate_estimated_cost(
  "anthropic/claude-3-5-sonnet",
  input_tokens: 2000,
  output_tokens: 1000
)

if cost > 0.10
  puts "Request too expensive, using cheaper model"
  model = OpenRouter::ModelSelector.new
                                   .within_budget(max_cost: 0.005)
                                   .choose
end

# Use generation stats to track actual costs
response = client.complete(messages, model: model)
if response["id"]
  stats = client.query_generation_stats(response["id"])
  puts "Actual cost: $#{stats['cost']}"
end
```

## Testing

The gem includes comprehensive test coverage with VCR integration for real API testing.

### Running Tests

```bash
# Run all tests
bundle exec rspec

# Run with documentation format
bundle exec rspec --format documentation

# Run specific test types
bundle exec rspec spec/unit/           # Unit tests only
bundle exec rspec spec/vcr/            # VCR integration tests (requires API key)
```

### VCR Testing

The project includes VCR tests that record real API interactions:

```bash
# Set API key for VCR tests
export OPENROUTER_API_KEY="your_api_key"

# Run VCR tests
bundle exec rspec spec/vcr/

# Re-record cassettes (deletes old recordings)
rm -rf spec/fixtures/vcr_cassettes/
bundle exec rspec spec/vcr/
```

## API Reference

### Client Methods

```ruby
client = OpenRouter::Client.new

# Chat completions
client.complete(messages, **options)

# Model information
client.models
client.query_generation_stats(generation_id)
```

### Enhanced Classes

```ruby
# Tool definition
OpenRouter::Tool.define { ... }
OpenRouter::Tool.from_hash(definition)

# Schema definition
OpenRouter::Schema.define(name) { ... }
OpenRouter::Schema.from_hash(name, definition)

# Model selection
OpenRouter::ModelSelector.new
  .require(*capabilities)
  .optimize_for(strategy)
  .choose

# Model registry
OpenRouter::ModelRegistry.all_models
OpenRouter::ModelRegistry.get_model_info(model)
OpenRouter::ModelRegistry.calculate_estimated_cost(model, tokens)
```

### Error Classes

```ruby
OpenRouter::Error                    # Base error class
OpenRouter::ConfigurationError       # Configuration issues
OpenRouter::ServerError             # API errors
OpenRouter::ToolCallError           # Tool execution errors
OpenRouter::SchemaValidationError   # Schema validation errors
OpenRouter::StructuredOutputError   # JSON parsing errors
OpenRouter::ModelRegistryError      # Model registry errors
OpenRouter::ModelSelectionError     # Model selection errors
```

### Configuration Options

```ruby
OpenRouter.configure do |config|
  config.access_token = "..."
  config.site_name = "..."
  config.site_url = "..."
  config.request_timeout = 120
  config.auto_heal_responses = true
  config.healer_model = "openai/gpt-4o-mini"
  config.max_heal_attempts = 2
  config.strict_mode = true
  config.auto_force_on_unsupported_models = true
end
```

## Contributing

Bug reports and pull requests are welcome on GitHub at <https://github.com/estiens/open_router>. 

This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](https://www.contributor-covenant.org/) code of conduct.

### Development Setup

```bash
git clone https://github.com/estiens/open_router.git
cd open_router
bundle install
bundle exec rspec
```

### Running Examples

```bash
# Set your API key
export OPENROUTER_API_KEY="your_key_here"

# Run examples
ruby -I lib examples/tool_calling_example.rb
ruby -I lib examples/structured_outputs_example.rb
ruby -I lib examples/model_selection_example.rb
```

## Acknowledgments

This enhanced fork builds upon the excellent foundation laid by [Obie Fernandez](https://github.com/obie) and the original OpenRouter Ruby gem. The original library was bootstrapped from the [Anthropic gem](https://github.com/alexrudall/anthropic) by [Alex Rudall](https://github.com/alexrudall) and extracted from the codebase of [Olympia](https://olympia.chat), Obie's AI startup.

We extend our heartfelt gratitude to:

- **Obie Fernandez** - Original OpenRouter gem author and visionary
- **Alex Rudall** - Creator of the Anthropic gem that served as the foundation
- **The OpenRouter Team** - For creating an amazing unified AI API
- **The Ruby Community** - For continuous support and contributions

## Maintainer

This enhanced fork is maintained by:

**Eric Stiens**
- Email: hello@ericstiens.dev
- Website: [ericstiens.dev](http://ericstiens.dev)
- GitHub: [@estiens](https://github.com/estiens)

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

MIT License is chosen for maximum permissiveness and compatibility, allowing unrestricted use, modification, and distribution while maintaining attribution requirements.