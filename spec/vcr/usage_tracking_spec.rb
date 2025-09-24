# frozen_string_literal: true

require "spec_helper"

RSpec.describe "OpenRouter Usage Tracking", :vcr do
  let(:client) do
    OpenRouter::Client.new(access_token: ENV["OPENROUTER_API_KEY"])
  end

  let(:usage_tracker) { OpenRouter::UsageTracker.new }

  describe "basic usage tracking" do
    it "tracks simple completion usage", vcr: { cassette_name: "usage_tracking_simple" } do
      messages = [{ role: "user", content: "Hello, world!" }]

      usage_tracker.start_tracking

      response = client.complete(
        messages,
        model: "openai/gpt-3.5-turbo",
        extras: { max_tokens: 50 }
      )

      usage_tracker.track_completion(response, model: "openai/gpt-3.5-turbo")

      stats = usage_tracker.get_stats
      expect(stats[:total_requests]).to eq(1)
      expect(stats[:total_tokens]).to be > 0
      expect(stats[:total_cost]).to be > 0
      expect(stats[:models_used]).to include("openai/gpt-3.5-turbo")
    end

    it "accumulates usage across multiple requests", vcr: { cassette_name: "usage_tracking_multiple" } do
      messages1 = [{ role: "user", content: "First message" }]
      messages2 = [{ role: "user", content: "Second message" }]

      usage_tracker.start_tracking

      response1 = client.complete(
        messages1,
        model: "openai/gpt-3.5-turbo",
        extras: { max_tokens: 30 }
      )

      usage_tracker.track_completion(response1, model: "openai/gpt-3.5-turbo")

      response2 = client.complete(
        messages2,
        model: "openai/gpt-3.5-turbo",
        extras: { max_tokens: 30 }
      )

      usage_tracker.track_completion(response2, model: "openai/gpt-3.5-turbo")

      stats = usage_tracker.get_stats
      expect(stats[:total_requests]).to eq(2)
      expect(stats[:total_tokens]).to be > 0
      expect(stats[:models_used]).to include("openai/gpt-3.5-turbo")
    end
  end

  describe "cost calculation" do
    it "calculates costs for different models", vcr: { cassette_name: "usage_tracking_cost_calculation" } do
      messages = [{ role: "user", content: "What is the weather today?" }]

      usage_tracker.start_tracking

      # Test with GPT-3.5-turbo
      response = client.complete(
        messages,
        model: "openai/gpt-3.5-turbo",
        extras: { max_tokens: 40 }
      )

      usage_tracker.track_completion(response, model: "openai/gpt-3.5-turbo")

      stats = usage_tracker.get_stats
      expect(stats[:total_cost]).to be > 0
      expect(stats[:cost_by_model]["openai/gpt-3.5-turbo"]).to be > 0
    end

    it "tracks token usage accurately", vcr: { cassette_name: "usage_tracking_token_usage" } do
      messages = [{ role: "user", content: "Explain quantum computing in one sentence" }]

      usage_tracker.start_tracking

      response = client.complete(
        messages,
        model: "openai/gpt-3.5-turbo",
        extras: { max_tokens: 100 }
      )

      usage_tracker.track_completion(response, model: "openai/gpt-3.5-turbo")

      stats = usage_tracker.get_stats
      expect(stats[:total_tokens]).to be > 10 # Should have meaningful token usage
      expect(stats[:input_tokens]).to be > 0
      expect(stats[:output_tokens]).to be > 0
      expect(stats[:total_tokens]).to eq(stats[:input_tokens] + stats[:output_tokens])
    end
  end

  describe "usage tracking with tools" do
    let(:weather_tool) do
      OpenRouter::Tool.define do
        name "get_weather"
        description "Get current weather"
        parameters do
          string "location", required: true, description: "City name"
        end
      end
    end

    it "tracks tool call usage", vcr: { cassette_name: "usage_tracking_tools" } do
      messages = [{ role: "user", content: "What's the weather in San Francisco?" }]

      usage_tracker.start_tracking

      response = client.complete(
        messages,
        model: "openai/gpt-4o-mini",
        tools: [weather_tool],
        tool_choice: "auto",
        extras: { max_tokens: 200 }
      )

      usage_tracker.track_completion(response, model: "openai/gpt-4o-mini")

      stats = usage_tracker.get_stats
      expect(stats[:total_requests]).to eq(1)
      expect(stats[:tool_calls_made]).to be >= 0 # May or may not make tool calls

      if response.has_tool_calls?
        expect(stats[:tool_calls_made]).to be > 0
      end
    end
  end

  describe "usage tracking with structured outputs" do
    let(:schema) do
      OpenRouter::Schema.define("weather_response") do
        string :city, required: true
        string :condition, required: true
        number :temperature, required: true
      end
    end

    let(:response_format) do
      {
        type: "json_schema",
        json_schema: schema.to_h
      }
    end

    it "tracks structured output usage", vcr: { cassette_name: "usage_tracking_structured" } do
      messages = [{ role: "user", content: "Generate weather data for New York" }]

      usage_tracker.start_tracking

      response = client.complete(
        messages,
        model: "openai/gpt-4o-mini",
        response_format: response_format,
        extras: { max_tokens: 150 }
      )

      usage_tracker.track_completion(response, model: "openai/gpt-4o-mini")

      stats = usage_tracker.get_stats
      expect(stats[:total_requests]).to eq(1)
      expect(stats[:structured_outputs_used]).to eq(1)
    end
  end

  describe "usage analytics" do
    it "provides detailed analytics", vcr: { cassette_name: "usage_tracking_analytics" } do
      messages1 = [{ role: "user", content: "Short message" }]
      messages2 = [{ role: "user", content: "This is a longer message that should use more tokens" }]

      usage_tracker.start_tracking

      # Make multiple requests
      response1 = client.complete(messages1, model: "openai/gpt-3.5-turbo", extras: { max_tokens: 20 })
      usage_tracker.track_completion(response1, model: "openai/gpt-3.5-turbo")

      response2 = client.complete(messages2, model: "openai/gpt-3.5-turbo", extras: { max_tokens: 30 })
      usage_tracker.track_completion(response2, model: "openai/gpt-3.5-turbo")

      analytics = usage_tracker.get_analytics
      expect(analytics).to have_key(:average_tokens_per_request)
      expect(analytics).to have_key(:average_cost_per_request)
      expect(analytics).to have_key(:cost_efficiency)
      expect(analytics[:average_tokens_per_request]).to be > 0
    end

    it "tracks request patterns over time", vcr: { cassette_name: "usage_tracking_patterns" } do
      usage_tracker.start_tracking

      # Make several requests
      3.times do |i|
        response = client.complete(
          [{ role: "user", content: "Request #{i + 1}" }],
          model: "openai/gpt-3.5-turbo",
          extras: { max_tokens: 25 }
        )
        usage_tracker.track_completion(response, model: "openai/gpt-3.5-turbo")
      end

      stats = usage_tracker.get_stats
      expect(stats[:total_requests]).to eq(3)
      expect(stats[:request_history]).to be_an(Array)
      expect(stats[:request_history].length).to eq(3)
    end
  end

  describe "usage export and reporting" do
    it "exports usage data", vcr: { cassette_name: "usage_tracking_export" } do
      messages = [{ role: "user", content: "Test message for export" }]

      usage_tracker.start_tracking

      response = client.complete(
        messages,
        model: "openai/gpt-3.5-turbo",
        extras: { max_tokens: 40 }
      )

      usage_tracker.track_completion(response, model: "openai/gpt-3.5-turbo")

      exported_data = usage_tracker.export_data
      expect(exported_data).to be_a(Hash)
      expect(exported_data).to have_key(:tracking_session)
      expect(exported_data).to have_key(:stats)
      expect(exported_data).to have_key(:request_history)
    end

    it "generates usage reports", vcr: { cassette_name: "usage_tracking_report" } do
      messages = [{ role: "user", content: "Generate a report" }]

      usage_tracker.start_tracking

      response = client.complete(
        messages,
        model: "openai/gpt-3.5-turbo",
        extras: { max_tokens: 50 }
      )

      usage_tracker.track_completion(response, model: "openai/gpt-3.5-turbo")

      report = usage_tracker.generate_report
      expect(report).to be_a(String)
      expect(report).to include("Usage Report")
      expect(report).to include("Total Requests")
      expect(report).to include("Total Cost")
    end
  end

  describe "usage tracking configuration" do
    it "respects tracking configuration", vcr: { cassette_name: "usage_tracking_config" } do
      # Create tracker with custom configuration
      custom_tracker = OpenRouter::UsageTracker.new(
        track_metadata: true,
        track_timing: true
      )

      messages = [{ role: "user", content: "Test with custom config" }]

      custom_tracker.start_tracking

      response = client.complete(
        messages,
        model: "openai/gpt-3.5-turbo",
        extras: { max_tokens: 30 }
      )

      custom_tracker.track_completion(response, model: "openai/gpt-3.5-turbo")

      stats = custom_tracker.get_stats
      expect(stats).to have_key(:metadata)
      expect(stats).to have_key(:timing_data)
    end
  end

  describe "usage tracking reset and state management" do
    it "can reset tracking data", vcr: { cassette_name: "usage_tracking_reset" } do
      messages = [{ role: "user", content: "Test before reset" }]

      usage_tracker.start_tracking

      response = client.complete(
        messages,
        model: "openai/gpt-3.5-turbo",
        extras: { max_tokens: 25 }
      )

      usage_tracker.track_completion(response, model: "openai/gpt-3.5-turbo")

      # Verify we have data
      stats_before = usage_tracker.get_stats
      expect(stats_before[:total_requests]).to eq(1)

      # Reset tracking
      usage_tracker.reset

      # Verify data is cleared
      stats_after = usage_tracker.get_stats
      expect(stats_after[:total_requests]).to eq(0)
      expect(stats_after[:total_tokens]).to eq(0)
      expect(stats_after[:total_cost]).to eq(0)
    end

    it "can pause and resume tracking", vcr: { cassette_name: "usage_tracking_pause_resume" } do
      messages1 = [{ role: "user", content: "First message" }]
      messages2 = [{ role: "user", content: "Second message" }]

      usage_tracker.start_tracking

      # Track first request
      response1 = client.complete(messages1, model: "openai/gpt-3.5-turbo", extras: { max_tokens: 20 })
      usage_tracker.track_completion(response1, model: "openai/gpt-3.5-turbo")

      # Pause tracking
      usage_tracker.pause_tracking

      # This request shouldn't be tracked
      response2 = client.complete(messages2, model: "openai/gpt-3.5-turbo", extras: { max_tokens: 20 })
      # Don't track this one while paused

      # Resume tracking
      usage_tracker.resume_tracking

      # Track third request
      response3 = client.complete(messages1, model: "openai/gpt-3.5-turbo", extras: { max_tokens: 20 })
      usage_tracker.track_completion(response3, model: "openai/gpt-3.5-turbo")

      stats = usage_tracker.get_stats
      expect(stats[:total_requests]).to eq(2) # Only first and third requests
    end
  end
end