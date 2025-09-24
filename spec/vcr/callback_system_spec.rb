# frozen_string_literal: true

require "spec_helper"

RSpec.describe "OpenRouter Callback System", :vcr do
  let(:client) do
    OpenRouter::Client.new(access_token: ENV["OPENROUTER_API_KEY"])
  end

  let(:messages) do
    [{ role: "user", content: "Hello, world!" }]
  end

  describe "request callbacks" do
    it "executes before_request callbacks", vcr: { cassette_name: "callbacks_before_request" } do
      callback_data = {}

      client.add_callback :before_request do |event_data|
        callback_data[:before_request] = event_data
        callback_data[:timestamp] = Time.now
      end

      response = client.complete(
        messages,
        model: "openai/gpt-3.5-turbo",
        extras: { max_tokens: 20 }
      )

      expect(callback_data).to have_key(:before_request)
      expect(callback_data[:before_request]).to include(
        event: :before_request,
        model: "openai/gpt-3.5-turbo",
        messages: messages
      )
      expect(callback_data[:before_request][:parameters]).to be_a(Hash)
      expect(response).to be_a(OpenRouter::Response)
    end

    it "executes after_request callbacks", vcr: { cassette_name: "callbacks_after_request" } do
      callback_data = {}

      client.add_callback :after_request do |event_data|
        callback_data[:after_request] = event_data
      end

      response = client.complete(
        messages,
        model: "openai/gpt-3.5-turbo",
        extras: { max_tokens: 20 }
      )

      expect(callback_data).to have_key(:after_request)
      expect(callback_data[:after_request]).to include(
        event: :after_request,
        model: "openai/gpt-3.5-turbo"
      )
      expect(callback_data[:after_request][:raw_response]).to be_a(Hash)
      expect(callback_data[:after_request][:response]).to be_a(OpenRouter::Response)
    end
  end

  describe "response callbacks" do
    it "executes before_response callbacks", vcr: { cassette_name: "callbacks_before_response" } do
      callback_data = {}

      client.add_callback :before_response do |event_data|
        callback_data[:before_response] = event_data
      end

      response = client.complete(
        messages,
        model: "openai/gpt-3.5-turbo",
        extras: { max_tokens: 20 }
      )

      expect(callback_data).to have_key(:before_response)
      expect(callback_data[:before_response]).to include(
        event: :before_response
      )
      expect(callback_data[:before_response][:raw_response]).to be_a(Hash)
    end

    it "executes after_response callbacks", vcr: { cassette_name: "callbacks_after_response" } do
      callback_data = {}

      client.add_callback :after_response do |event_data|
        callback_data[:after_response] = event_data
      end

      response = client.complete(
        messages,
        model: "openai/gpt-3.5-turbo",
        extras: { max_tokens: 20 }
      )

      expect(callback_data).to have_key(:after_response)
      expect(callback_data[:after_response]).to include(
        event: :after_response
      )
      expect(callback_data[:after_response][:response]).to be_a(OpenRouter::Response)
    end
  end

  describe "tool call callbacks" do
    let(:calculator_tool) do
      OpenRouter::Tool.define do
        name "add_numbers"
        description "Add two numbers together"
        parameters do
          number "a", required: true, description: "First number"
          number "b", required: true, description: "Second number"
        end
      end
    end

    it "executes tool_call_start callbacks", vcr: { cassette_name: "callbacks_tool_call_start" } do
      callback_data = {}

      client.add_callback :tool_call_start do |event_data|
        callback_data[:tool_call_start] = event_data
      end

      response = client.complete(
        [{ role: "user", content: "What is 5 + 3?" }],
        model: "openai/gpt-4o-mini",
        tools: [calculator_tool],
        extras: { max_tokens: 200 }
      )

      if response.has_tool_calls?
        # Execute the tool call to trigger callback
        tool_call = response.tool_calls.first
        tool_call.execute { |args| args["a"].to_i + args["b"].to_i }

        expect(callback_data).to have_key(:tool_call_start)
        expect(callback_data[:tool_call_start]).to include(
          event: :tool_call_start,
          tool_call_id: tool_call.id,
          function_name: "add_numbers"
        )
      end
    end

    it "executes tool_call_end callbacks", vcr: { cassette_name: "callbacks_tool_call_end" } do
      callback_data = {}

      client.add_callback :tool_call_end do |event_data|
        callback_data[:tool_call_end] = event_data
      end

      response = client.complete(
        [{ role: "user", content: "What is 7 + 4?" }],
        model: "openai/gpt-4o-mini",
        tools: [calculator_tool],
        extras: { max_tokens: 200 }
      )

      if response.has_tool_calls?
        tool_call = response.tool_calls.first
        result = tool_call.execute { |args| args["a"].to_i + args["b"].to_i }

        expect(callback_data).to have_key(:tool_call_end)
        expect(callback_data[:tool_call_end]).to include(
          event: :tool_call_end,
          tool_call_id: tool_call.id,
          function_name: "add_numbers",
          result: result
        )
      end
    end
  end

  describe "error callbacks" do
    it "executes request_error callbacks", vcr: { cassette_name: "callbacks_request_error" } do
      callback_data = {}
      bad_client = OpenRouter::Client.new(access_token: "invalid_token")

      bad_client.add_callback :request_error do |event_data|
        callback_data[:request_error] = event_data
      end

      expect do
        bad_client.complete(messages, model: "openai/gpt-3.5-turbo")
      end.to raise_error

      expect(callback_data).to have_key(:request_error)
      expect(callback_data[:request_error]).to include(
        event: :request_error
      )
      expect(callback_data[:request_error][:error]).to be_a(Exception)
    end

    it "executes callback_error callbacks when a callback fails", vcr: { cassette_name: "callbacks_callback_error" } do
      callback_data = {}

      client.add_callback :callback_error do |event_data|
        callback_data[:callback_error] = event_data
      end

      # Add a callback that will fail
      client.add_callback :before_request do |event_data|
        raise StandardError, "Intentional callback error"
      end

      response = client.complete(
        messages,
        model: "openai/gpt-3.5-turbo",
        extras: { max_tokens: 20 }
      )

      expect(callback_data).to have_key(:callback_error)
      expect(callback_data[:callback_error]).to include(
        event: :callback_error,
        error_message: "Intentional callback error"
      )
      expect(response).to be_a(OpenRouter::Response) # Should still complete
    end
  end

  describe "multiple callbacks" do
    it "executes all callbacks for the same event", vcr: { cassette_name: "callbacks_multiple" } do
      callback_data = {}

      client.add_callback :before_request do |event_data|
        callback_data[:callback1] = event_data[:model]
      end

      client.add_callback :before_request do |event_data|
        callback_data[:callback2] = event_data[:model]
      end

      response = client.complete(
        messages,
        model: "openai/gpt-3.5-turbo",
        extras: { max_tokens: 20 }
      )

      expect(callback_data[:callback1]).to eq("openai/gpt-3.5-turbo")
      expect(callback_data[:callback2]).to eq("openai/gpt-3.5-turbo")
    end

    it "executes callbacks in the order they were added", vcr: { cassette_name: "callbacks_order" } do
      execution_order = []

      client.add_callback :before_request do |event_data|
        execution_order << :first
      end

      client.add_callback :before_request do |event_data|
        execution_order << :second
      end

      response = client.complete(
        messages,
        model: "openai/gpt-3.5-turbo",
        extras: { max_tokens: 20 }
      )

      expect(execution_order).to eq([:first, :second])
    end
  end

  describe "callback data integrity" do
    it "provides complete request data in before_request", vcr: { cassette_name: "callbacks_request_data" } do
      callback_data = {}

      client.add_callback :before_request do |event_data|
        callback_data[:event_data] = event_data
      end

      response = client.complete(
        messages,
        model: "openai/gpt-3.5-turbo",
        extras: {
          max_tokens: 30,
          temperature: 0.5
        }
      )

      expect(callback_data[:event_data][:parameters]).to include(
        messages: messages,
        model: "openai/gpt-3.5-turbo",
        max_tokens: 30,
        temperature: 0.5
      )
    end

    it "provides response timing information", vcr: { cassette_name: "callbacks_timing" } do
      callback_data = {}

      client.add_callback :after_request do |event_data|
        callback_data[:timing] = event_data
      end

      response = client.complete(
        messages,
        model: "openai/gpt-3.5-turbo",
        extras: { max_tokens: 20 }
      )

      expect(callback_data[:timing]).to have_key(:duration_ms)
      expect(callback_data[:timing][:duration_ms]).to be_a(Numeric)
      expect(callback_data[:timing][:duration_ms]).to be > 0
    end
  end

  describe "callback removal" do
    it "can remove specific callbacks", vcr: { cassette_name: "callbacks_removal" } do
      callback_data = {}

      callback_proc = proc do |event_data|
        callback_data[:should_not_execute] = true
      end

      client.add_callback :before_request, &callback_proc
      client.remove_callback :before_request, callback_proc

      response = client.complete(
        messages,
        model: "openai/gpt-3.5-turbo",
        extras: { max_tokens: 20 }
      )

      expect(callback_data).not_to have_key(:should_not_execute)
    end

    it "can clear all callbacks for an event", vcr: { cassette_name: "callbacks_clear" } do
      callback_data = {}

      client.add_callback :before_request do |event_data|
        callback_data[:should_not_execute1] = true
      end

      client.add_callback :before_request do |event_data|
        callback_data[:should_not_execute2] = true
      end

      client.clear_callbacks :before_request

      response = client.complete(
        messages,
        model: "openai/gpt-3.5-turbo",
        extras: { max_tokens: 20 }
      )

      expect(callback_data).to be_empty
    end
  end

  describe "callback system with structured outputs" do
    let(:schema) do
      OpenRouter::Schema.define("test_response") do
        string :message, required: true
        integer :confidence, required: true
      end
    end

    let(:response_format) do
      {
        type: "json_schema",
        json_schema: schema.to_h
      }
    end

    it "includes structured output data in callbacks", vcr: { cassette_name: "callbacks_structured_output" } do
      callback_data = {}

      client.add_callback :after_response do |event_data|
        callback_data[:structured_data] = event_data
      end

      response = client.complete(
        [{ role: "user", content: "Generate a test message with confidence score" }],
        model: "openai/gpt-4o-mini",
        response_format: response_format,
        extras: { max_tokens: 100 }
      )

      structured = response.structured_output

      expect(callback_data[:structured_data][:response]).to be_a(OpenRouter::Response)
      expect(structured).to be_a(Hash)
    end
  end
end