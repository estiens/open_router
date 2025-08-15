# OpenRouter

The future will bring us hundreds of language models and dozens of providers for each. How will you choose the best?

The [OpenRouter API](https://openrouter.ai/docs) is a single unified interface for all LLMs! And now you can easily use it with Ruby! 🤖🌌

## Features

- **Prioritize price or performance**: OpenRouter scouts for the lowest prices and best latencies/throughputs across dozens of providers, and lets you choose how to prioritize them.
- **Standardized API**: No need to change your code when switching between models or providers. You can even let users choose and pay for their own.
- **Easy integration**: This Ruby gem provides a simple and intuitive interface to interact with the OpenRouter API, making it effortless to integrate AI capabilities into your Ruby applications.

### ✨ Enhanced Features (This Fork)

- **🛠️ Tool Calling**: Full support for OpenRouter's function calling API with Ruby-idiomatic DSL for tool definitions
- **📋 Structured Outputs**: JSON Schema validation with OpenRouter's structured output API and Ruby DSL for schema definitions
- **🎯 Smart Model Selection**: Intelligent model selection with fluent DSL for cost optimization, capability requirements, and provider preferences
- **📊 Model Registry**: Local caching and querying of OpenRouter model data with capability detection
- **🔄 Enhanced Response Handling**: Rich Response objects with automatic parsing for tool calls and structured outputs
- **✅ Backward Compatible**: All existing code continues to work unchanged

👬 This Ruby library was originally bootstrapped from the [🤖 Anthropic](https://github.com/alexrudall/anthropic) gem by Alex Rudall, and subsequently extracted from the codebase of my fast-growing AI startup called [Olympia](https://olympia.chat?utm_source=open_router_gem&utm_medium=github) that lets you add AI-powered consultants to your startup!

🚢 Need someone to develop AI software for you using modern Ruby on Rails? My other company Magma Labs does exactly that: [magmalabs.io](https://www.magmalabs.io/?utm_source=open_router_gem&utm_medium=github). In fact, we also sell off-the-shelf solutions based on my early work on the field, via a platform called [MagmaChat](https://magmachat.ai?utm_source=open_router_gem&utm_medium=github)


[🐦 Olympia's Twitter](https://twitter.com/OlympiaChat) | [🐦 Obie's Twitter](https://twitter.com/OlympiaChat) | [🎮 Ruby AI Builders Discord](https://discord.gg/k4Uc224xVD)

### Bundler

Add this line to your application's Gemfile:

```ruby
gem "open_router"
```

And then execute:

$ bundle install

### Gem install

Or install with:

$ gem install open_router

and require with:

```ruby
require "open_router"
```

## Usage

- Get your API key from [https://openrouter.ai/keys](https://openrouter.ai/keys)

### Quickstart

Configure the gem with your API keys, for example in an `open_router.rb` initializer file. Never hardcode secrets into your codebase - instead use `Rails.application.credentials` or something like [dotenv](https://github.com/motdotla/dotenv) to pass the keys safely into your environments.

```ruby
OpenRouter.configure do |config|
  config.access_token = Rails.application.credentials.open_router[:access_token]
  config.site_name = 'Olympia'
  config.site_url = 'https://olympia.chat'
end
```

Then you can create a client like this:

```ruby
client = OpenRouter::Client.new
```

#### Configure Faraday

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

### Completions

Hit the OpenRouter API for a completion:

```ruby
messages = [
  { role: "system", content: "You are a helpful assistant." },
  { role: "user", content: "What is the color of the sky?" }
]

response = client.complete(messages)
puts response["choices"][0]["message"]["content"]
# => "The sky is typically blue during the day due to a phenomenon called Rayleigh scattering. Sunlight..."
```

### Models

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

### Tool Calling / Function Calling

The enhanced gem supports OpenRouter's tool calling feature with a rich Ruby DSL for defining and managing tools:

#### Defining Tools

```ruby
# Define a tool using the DSL
search_tool = OpenRouter::Tool.define do
  name "search_web"
  description "Search the web for information"
  
  parameters do
    string :query, required: true, description: "Search query"
    integer :max_results, description: "Maximum results to return", minimum: 1, maximum: 100
    boolean :include_images, description: "Include image results"
    array :categories, description: "Search categories", items: { type: "string" }
  end
end

# Alternative: Define using hash format for complex scenarios
calculator_tool = OpenRouter::Tool.define do
  name "calculator"
  description "Perform mathematical calculations"
  
  parameters do
    object :calculation do
      string :operation, required: true, enum: ["add", "subtract", "multiply", "divide"]
      array :operands, required: true, items: { type: "number" }
      boolean :precise, description: "Use high precision mode"
    end
  end
end

# Or define from a hash directly
weather_tool = OpenRouter::Tool.from_hash({
  name: "get_weather",
  description: "Get current weather for a location",
  parameters: {
    type: "object",
    properties: {
      location: {
        type: "string",
        description: "City name or coordinates"
      },
      units: {
        type: "string",
        enum: ["celsius", "fahrenheit"],
        default: "celsius"
      }
    },
    required: ["location"]
  }
})
```

#### Using Tools in Completions

```ruby
tools = [search_tool, calculator_tool, weather_tool]

response = client.complete(
  [{ role: "user", content: "Search for Ruby tutorials and calculate 15 * 23" }],
  model: "anthropic/claude-3.5-sonnet",
  tools: tools,
  tool_choice: "auto"  # or "required", "none", or specific tool name
)

# Handle tool calls
if response.has_tool_calls?
  messages = [{ role: "user", content: "Search for Ruby tutorials and calculate 15 * 23" }]
  messages << response.to_message
  
  response.tool_calls.each do |tool_call|
    puts "Tool: #{tool_call.name}"
    puts "Arguments: #{tool_call.arguments}"
    puts "ID: #{tool_call.id}"
    
    # Execute your tool logic
    result = case tool_call.name
    when "search_web"
      execute_search(tool_call.arguments["query"], tool_call.arguments["max_results"])
    when "calculator"
      perform_calculation(tool_call.arguments["calculation"])
    when "get_weather"
      fetch_weather(tool_call.arguments["location"], tool_call.arguments["units"])
    end
    
    # Add tool result to conversation
    messages << tool_call.to_result_message(result)
  end
  
  # Continue conversation with results
  final_response = client.complete(messages, tools: tools)
  puts final_response.content
end
```

#### Tool Call Helpers

```ruby
# Tool validation
tool_call.valid?  # Check if arguments match schema

# Convert to OpenRouter API format
tool_call.to_api_format

# Create result messages
tool_call.to_result_message("Search completed successfully")
tool_call.to_result_message({ results: [...], count: 10 })

# Handle errors gracefully
begin
  result = execute_tool(tool_call)
  tool_call.to_result_message(result)
rescue StandardError => e
  tool_call.to_result_message("Error: #{e.message}")
end
```

### Structured Outputs

Get JSON responses that conform to a specific schema:

```ruby
# Define a schema using the DSL
weather_schema = OpenRouter::Schema.define("weather") do
  string :location, required: true, description: "City name"
  number :temperature, required: true, description: "Temperature in Celsius"
  string :conditions, required: true, description: "Weather conditions"
  no_additional_properties
end

# Get structured response
response = client.complete(
  [{ role: "user", content: "What's the weather in London?" }],
  model: "openai/gpt-4o",
  response_format: weather_schema
)

# Access parsed JSON data
weather = response.structured_output
puts weather["location"]     # => "London"
puts weather["temperature"]  # => 15
puts weather["conditions"]   # => "Partly cloudy"

# Validate against schema (requires json-schema gem)
if response.valid_structured_output?
  puts "Response is valid!"
else
  puts "Validation errors: #{response.validation_errors}"
end
```

### Smart Model Selection

The gem includes intelligent model selection capabilities that help you choose the best model based on your requirements:

```ruby
# Basic usage - find cheapest model with function calling
selector = OpenRouter::ModelSelector.new
model = selector.require(:function_calling)
              .optimize_for(:cost)
              .choose

# Advanced selection with multiple criteria
model = OpenRouter::ModelSelector.new
                                 .require(:function_calling, :vision)
                                 .within_budget(max_cost: 0.01)
                                 .min_context(50000)
                                 .prefer_providers("anthropic", "openai")
                                 .optimize_for(:performance)
                                 .choose

# Get multiple options with fallbacks
models = OpenRouter::ModelSelector.new
                                  .require(:structured_outputs)
                                  .optimize_for(:cost)
                                  .choose_with_fallbacks(limit: 3)
# => ["openai/gpt-4o-mini", "anthropic/claude-3-haiku", "google/gemini-flash"]

# Graceful degradation when requirements can't be met
model = OpenRouter::ModelSelector.new
                                 .require(:function_calling)
                                 .within_budget(max_cost: 0.001)  # Very strict budget
                                 .choose_with_fallback  # Falls back by relaxing requirements
```

#### Available Selection Criteria

- **Capabilities**: `:function_calling`, `:structured_outputs`, `:vision`, `:long_context`
- **Optimization strategies**: `:cost`, `:performance`, `:latest`, `:context`
- **Budget constraints**: `max_cost`, `max_output_cost`
- **Context requirements**: `min_context`
- **Provider preferences**: `prefer_providers`, `require_providers`, `avoid_providers`
- **Model patterns**: `avoid_patterns` (glob patterns like `*-preview`)
- **Release date**: `newer_than`

### Model Registry

Query model information and capabilities:

```ruby
# Get all available models
models = OpenRouter::ModelRegistry.all_models

# Check if a model supports specific capabilities
model_info = OpenRouter::ModelRegistry.get_model_info("anthropic/claude-3-5-sonnet")
puts model_info[:capabilities]  # [:chat, :function_calling, :structured_outputs, :vision]

# Find models matching requirements
candidates = OpenRouter::ModelRegistry.models_meeting_requirements(
  capabilities: [:function_calling],
  max_input_cost: 0.01
)

# Estimate costs
cost = OpenRouter::ModelRegistry.calculate_estimated_cost(
  "openai/gpt-4o",
  input_tokens: 1000,
  output_tokens: 500
)
puts "Estimated cost: $#{cost}"

# Refresh model data from API
OpenRouter::ModelRegistry.refresh!
```

### Query Generation Stats

Query the generation stats for a given generation ID:

```ruby
generation_id = "generation-abcdefg"
stats = client.query_generation_stats(generation_id)
puts stats
# => {"id"=>"generation-abcdefg", "object"=>"generation", "created"=>1684195200, "model"=>"openrouter/auto", "usage"=>{"prompt_tokens"=>10, "completion_tokens"=>50, "total_tokens"=>60}, "cost"=>0.0006}
```

## Errors

The client will raise an `OpenRouter::ServerError` in the case of an error returned from a completion (or empty response).

## Contributing

Bug reports and pull requests are welcome on GitHub at <https://github.com/OlympiaAI/open_router>. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/OlympiaAI/open_router/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
