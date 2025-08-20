#!/usr/bin/env ruby
# frozen_string_literal: true

# Debug tool to test OpenRouter API connectivity and validate requests
# Run with: ruby debug_api.rb

require_relative "lib/open_router"

def test_api_connectivity
  puts "Testing OpenRouter API connectivity..."

  # Check if API key is set
  api_key = ENV["OPENROUTER_API_KEY"] || ENV["ACCESS_TOKEN"]
  if api_key.nil? || api_key.empty?
    puts "❌ ERROR: No API key found. Set OPENROUTER_API_KEY environment variable."
    return false
  end

  puts "✅ API key found (length: #{api_key.length})"

  # Test basic completion
  begin
    client = OpenRouter::Client.new(access_token: api_key)

    puts "\nTesting basic completion..."
    response = client.complete([{ role: "user", content: "Hello" }], model: "openai/gpt-3.5-turbo", extras: { max_tokens: 10 })
    puts "✅ Basic completion successful"
    puts "Response: #{response.content}"

    # Test structured output
    puts "\nTesting structured output..."
    schema = OpenRouter::Schema.define("test") do
      string :message, required: true
    end

    response = client.complete(
      [{ role: "user", content: "Say hello" }],
      model: "openai/gpt-4o-mini",
      response_format: schema,
      extras: { max_tokens: 50 }
    )

    puts "✅ Structured output successful"
    puts "Structured result: #{response.structured_output}"

    true
  rescue OpenRouter::ServerError => e
    puts "❌ Server Error: #{e.message}"
    if e.message.include?("400")
      puts "   This usually means invalid request parameters or authentication issues"
    elsif e.message.include?("401")
      puts "   This means authentication failed - check your API key"
    elsif e.message.include?("429")
      puts "   This means rate limiting - wait and try again"
    end
    false
  rescue StandardError => e
    puts "❌ Unexpected Error: #{e.class} - #{e.message}"
    puts "   Full backtrace:\n   #{e.backtrace.join("\n   ")}"
    false
  end
end

def validate_test_schemas
  puts "\nValidating test schemas..."

  # Test the schemas used in VCR tests
  begin
    simple_schema = OpenRouter::Schema.define("message") do
      string "content", required: true, description: "The message content"
      integer "count", required: true, description: "A count value"
      object "metadata", required: false do
        boolean "completed", required: false, description: "Whether task is completed"
      end
      integer "total_count", required: true, description: "Total number of tasks"
    end

    puts "✅ Simple schema validates correctly"
    puts "Schema: #{simple_schema.to_h.to_json}"
  rescue StandardError => e
    puts "❌ Schema validation failed: #{e.message}"
    return false
  end

  true
end

if __FILE__ == $PROGRAM_NAME
  puts "OpenRouter API Debug Tool"
  puts "=" * 40

  api_ok = test_api_connectivity
  schema_ok = validate_test_schemas

  puts "\n#{"=" * 40}"
  if api_ok && schema_ok
    puts "✅ All tests passed! VCR cassettes can be safely re-recorded with:"
    puts "   VCR_RECORD_ALL=true bundle exec rspec spec/vcr/"
  else
    puts "❌ Issues found. Fix the above problems before re-recording VCR cassettes."
  end
end
