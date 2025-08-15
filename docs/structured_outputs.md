# Structured Outputs

The OpenRouter gem provides comprehensive support for structured outputs using JSON Schema validation. This feature ensures that AI model responses conform to specific formats, making them easy to parse and integrate into your applications.

## Quick Start

```ruby
# Define a schema
user_schema = OpenRouter::Schema.define("user") do
  string :name, required: true, description: "User's full name"
  integer :age, required: true, description: "User's age", minimum: 0, maximum: 150
  string :email, required: true, description: "Valid email address"
  boolean :premium, description: "Premium account status"
end

# Use with completion
response = client.complete(
  [{ role: "user", content: "Create a user profile for John Doe, age 30, john@example.com" }],
  model: "openai/gpt-4o",
  response_format: user_schema
)

# Access structured data
user = response.structured_output
puts user["name"]    # => "John Doe"
puts user["age"]     # => 30
puts user["email"]   # => "john@example.com"
puts user["premium"] # => false
```

## Schema Definition DSL

The gem provides a fluent DSL for defining JSON schemas with validation rules:

### Basic Types

```ruby
schema = OpenRouter::Schema.define("example") do
  # String properties
  string :name, required: true, description: "Name field"
  string :category, enum: ["A", "B", "C"], description: "Category selection"
  string :content, min_length: 10, max_length: 1000
  
  # Numeric properties
  integer :count, minimum: 0, maximum: 100
  number :price, minimum: 0.01, description: "Price in USD"
  
  # Boolean properties
  boolean :active, description: "Active status"
  
  # Additional validation
  no_additional_properties  # Strict schema - no extra fields allowed
end
```

### Complex Objects

```ruby
order_schema = OpenRouter::Schema.define("order") do
  string :id, required: true, description: "Order ID"
  
  # Nested object
  object :customer, required: true do
    string :name, required: true
    string :email, required: true
    object :address do
      string :street, required: true
      string :city, required: true
      string :zip_code, required: true
    end
  end
  
  # Array of objects
  array :items, required: true, description: "Order items" do
    items do
      object do
        string :product_id, required: true
        integer :quantity, required: true, minimum: 1
        number :unit_price, required: true, minimum: 0
      end
    end
  end
  
  # Simple array
  array :tags, description: "Order tags", items: { type: "string" }
  
  number :total, required: true, minimum: 0
  no_additional_properties
end
```

### Advanced Features

```ruby
advanced_schema = OpenRouter::Schema.define("advanced") do
  # Conditional schemas
  string :type, required: true, enum: ["personal", "business"]
  
  # You can add conditional logic in your application code
  # based on the type field
  
  # Pattern matching for strings
  string :phone, pattern: "^\\+?[1-9]\\d{1,14}$", description: "Phone number"
  
  # Multiple types (union types)
  # Note: JSON Schema supports this, but implementation depends on the model
  
  # Default values
  string :status, default: "pending", enum: ["pending", "active", "inactive"]
  
  # Rich descriptions for better model understanding
  string :description, 
         description: "Detailed description of the item (minimum 50 characters for quality)", 
         min_length: 50
end
```

## Schema from Hash

For complex schemas or when migrating from existing JSON schemas:

```ruby
api_response_schema = OpenRouter::Schema.from_hash("api_response", {
  type: "object",
  properties: {
    success: { type: "boolean" },
    data: {
      type: "object",
      properties: {
        users: {
          type: "array",
          items: {
            type: "object",
            properties: {
              id: { type: "integer" },
              username: { type: "string", minLength: 3 },
              profile: {
                type: "object",
                properties: {
                  bio: { type: "string" },
                  avatar_url: { type: "string", format: "uri" }
                }
              }
            },
            required: ["id", "username"]
          }
        }
      }
    },
    pagination: {
      type: "object",
      properties: {
        page: { type: "integer", minimum: 1 },
        total: { type: "integer", minimum: 0 },
        has_more: { type: "boolean" }
      },
      required: ["page", "total", "has_more"]
    }
  },
  required: ["success", "data"]
})
```

## Response Handling

### Basic Usage

```ruby
response = client.complete(messages, response_format: schema)

# Check if response has structured output
if response.has_structured_output?
  data = response.structured_output
  # Process structured data
else
  # Handle fallback to regular text response
  content = response.content
end
```

### Validation

```ruby
# Validate response against schema (requires json-schema gem)
if response.valid_structured_output?
  puts "Response is valid!"
  data = response.structured_output
else
  puts "Validation errors:"
  response.validation_errors.each { |error| puts "- #{error}" }
  
  # You might still want to use the data despite validation errors
  data = response.structured_output
end
```

### Error Handling

```ruby
begin
  response = client.complete(messages, response_format: schema)
  data = response.structured_output
rescue OpenRouter::StructuredOutputError => e
  puts "Failed to parse structured output: #{e.message}"
  # Fall back to regular content
  content = response.content
rescue OpenRouter::SchemaValidationError => e
  puts "Schema validation failed: #{e.message}"
  # Data might still be accessible but invalid
  data = response.structured_output
end
```

## Best Practices

### Schema Design

1. **Be Specific**: Provide clear descriptions for better model understanding
2. **Use Constraints**: Set appropriate min/max values, string lengths, and enums
3. **Required Fields**: Mark essential fields as required
4. **No Extra Properties**: Use `no_additional_properties` for strict schemas

```ruby
# Good: Clear, constrained schema
product_schema = OpenRouter::Schema.define("product") do
  string :name, required: true, description: "Product name (2-100 characters)", 
         min_length: 2, max_length: 100
  string :category, required: true, enum: ["electronics", "clothing", "books"], 
         description: "Product category"
  number :price, required: true, minimum: 0.01, maximum: 999999.99, 
         description: "Price in USD"
  integer :stock, required: true, minimum: 0, 
          description: "Current stock quantity"
  no_additional_properties
end
```

### Model Selection

Different models have varying support for structured outputs:

```ruby
# Select a model that supports structured outputs
model = OpenRouter::ModelSelector.new
                                 .require(:structured_outputs)
                                 .optimize_for(:cost)
                                 .choose

response = client.complete(messages, model: model, response_format: schema)
```

### Fallback Strategies

```ruby
def safe_structured_completion(messages, schema, client)
  # Try with structured output first
  begin
    response = client.complete(messages, response_format: schema)
    return { data: response.structured_output, type: :structured }
  rescue OpenRouter::StructuredOutputError
    # Fall back to regular completion with instructions
    fallback_messages = messages + [{
      role: "system", 
      content: "Please respond with valid JSON matching this schema: #{schema.to_json_schema}"
    }]
    
    response = client.complete(fallback_messages)
    begin
      data = JSON.parse(response.content)
      return { data: data, type: :parsed }
    rescue JSON::ParserError
      return { data: response.content, type: :text }
    end
  end
end
```

### Debugging

```ruby
# Enable debug mode to see schema being sent
schema = OpenRouter::Schema.define("debug_example") do
  string :result, required: true
end

puts "Schema being sent:"
puts JSON.pretty_generate(schema.to_json_schema)

response = client.complete(messages, response_format: schema)

puts "Raw response:"
puts response["choices"][0]["message"]["content"]

puts "Parsed structured output:"
puts response.structured_output.inspect
```

### Response Healing

The gem includes automatic healing for malformed JSON responses from models that don't natively support structured outputs:

```ruby
# Configure healing globally
OpenRouter.configure do |config|
  config.auto_heal_responses = true
  config.healer_model = "openai/gpt-4o-mini"
  config.max_heal_attempts = 2
end

# When using models without native structured output support,
# the gem automatically attempts to heal malformed responses
response = client.complete(
  [{ role: "user", content: "Generate user data for John Doe" }],
  model: "some/model-without-native-support",
  response_format: user_schema
)

# The response will be automatically healed if the JSON is malformed
user = response.structured_output  # Parsed and potentially healed
```

#### How Healing Works

1. **Detection**: If JSON parsing fails, healing is triggered
2. **Healing Request**: The healer model receives the original schema and malformed response
3. **Correction**: The healer attempts to fix the JSON while preserving semantic content
4. **Validation**: The healed response is validated against the original schema
5. **Fallback**: If healing fails, the original error is preserved

#### Healing Configuration

```ruby
OpenRouter.configure do |config|
  # Enable/disable automatic healing
  config.auto_heal_responses = true
  
  # Model to use for healing (should be reliable with JSON)
  config.healer_model = "openai/gpt-4o-mini"
  
  # Maximum healing attempts before giving up
  config.max_heal_attempts = 2
  
  # Whether to automatically force structured outputs on unsupported models
  config.auto_force_on_unsupported_models = true
end
```

## Common Patterns

### API Response Wrapper

```ruby
api_wrapper_schema = OpenRouter::Schema.define("api_wrapper") do
  boolean :success, required: true, description: "Whether the operation succeeded"
  string :message, description: "Human-readable message"
  object :data, description: "Response payload"
  array :errors, description: "List of error messages", items: { type: "string" }
end
```

### Data Extraction

```ruby
extraction_schema = OpenRouter::Schema.define("extraction") do
  array :entities, required: true, description: "Extracted entities" do
    items do
      object do
        string :type, required: true, enum: ["person", "organization", "location"]
        string :name, required: true, description: "Entity name"
        number :confidence, required: true, minimum: 0, maximum: 1
        integer :start_pos, description: "Start position in text"
        integer :end_pos, description: "End position in text"
      end
    end
  end
  
  object :summary, required: true do
    string :main_topic, required: true
    array :key_points, required: true, items: { type: "string" }
    string :sentiment, enum: ["positive", "negative", "neutral"]
  end
end
```

### Configuration Objects

```ruby
config_schema = OpenRouter::Schema.define("config") do
  object :database, required: true do
    string :host, required: true
    integer :port, required: true, minimum: 1, maximum: 65535
    string :name, required: true
    boolean :ssl, default: true
  end
  
  object :cache do
    string :type, enum: ["redis", "memcached", "memory"], default: "memory"
    integer :ttl, minimum: 1, default: 3600
  end
  
  array :features, items: { type: "string" }
  no_additional_properties
end
```

## Troubleshooting

### Common Issues

1. **Schema Too Complex**: Large, deeply nested schemas may cause model confusion
2. **Conflicting Constraints**: Ensure min/max values and enums are logically consistent
3. **Model Limitations**: Not all models support structured outputs equally well
4. **JSON Parsing Errors**: Models may return malformed JSON despite schema constraints

### Solutions

```ruby
# 1. Simplify complex schemas
simple_schema = OpenRouter::Schema.define("simple") do
  # Flatten nested structures where possible
  string :user_name, required: true
  string :user_email, required: true
  string :order_id, required: true
  number :order_total, required: true
end

# 2. Add extra validation in your code
def validate_response_data(data, custom_rules = {})
  errors = []
  
  # Custom business logic validation
  errors << "Invalid email format" unless data["email"]&.include?("@")
  errors << "Price too low" if data["price"].to_f < 0.01
  
  errors
end

# 3. Use model selection
best_model = OpenRouter::ModelSelector.new
                                      .require(:structured_outputs)
                                      .optimize_for(:performance)
                                      .choose

# 4. Implement retry logic with fallbacks
def robust_structured_completion(messages, schema, max_retries: 3)
  retries = 0
  
  begin
    response = client.complete(messages, response_format: schema)
    response.structured_output
  rescue OpenRouter::StructuredOutputError => e
    retries += 1
    if retries <= max_retries
      sleep(retries * 0.5)  # Back off
      retry
    else
      raise e
    end
  end
end
```