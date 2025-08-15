#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "lib/open_router"

# Check if API key is available
unless ENV["OPENROUTER_API_KEY"]
  puts "❌ No OPENROUTER_API_KEY found. Set environment variable and try again."
  exit 1
end

puts "🧪 Testing structured output fix with real OpenRouter API call..."

client = OpenRouter::Client.new(access_token: ENV["OPENROUTER_API_KEY"])

# Create a simple schema
schema = OpenRouter::Schema.define("simple_person") do
  string :name, required: true, description: "Person's name"
  integer :age, required: true, description: "Person's age in years"
  string :occupation, required: false, description: "Person's job"
end

puts "\n📋 Schema format being sent:"
puts JSON.pretty_generate(client.send(:serialize_response_format, schema))

messages = [
  {
    role: "user",
    content: "Create JSON for a person named Alice who is 28 years old and works as a software engineer."
  }
]

begin
  puts "\n🚀 Making API request..."

  response = client.complete(
    messages,
    model: "openai/gpt-4o-mini", # Use a model that supports structured outputs
    response_format: schema,
    extras: { max_tokens: 200, temperature: 0.1 }
  )

  puts "✅ API request succeeded!"
  puts "\n📨 Raw response content:"
  puts response.content

  puts "\n📊 Structured output:"
  structured = response.structured_output
  puts structured.inspect

  puts "\n🧪 Validation checks:"
  puts "- Name is string: #{structured["name"].is_a?(String)}"
  puts "- Age is integer: #{structured["age"].is_a?(Integer)}"
  puts "- Has name 'Alice': #{structured["name"]&.include?("Alice")}"
  puts "- Age is 28: #{structured["age"] == 28}"

  puts "- Has occupation: #{structured["occupation"]}" if structured["occupation"]

  puts "\n🎉 Test completed successfully! The 400 BadRequestError issue has been fixed."
rescue StandardError => e
  puts "❌ Test failed with error:"
  puts "Error class: #{e.class.name}"
  puts "Error message: #{e.message}"

  if e.is_a?(OpenRouter::ServerError) && e.message.include?("400")
    puts "\n🔍 This is still the 400 error we're trying to fix."
    puts "The schema serialization may still have issues."
  else
    puts "\n📝 This might be a different issue (API key, network, model availability, etc.)"
  end

  exit 1
end
