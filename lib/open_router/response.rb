# frozen_string_literal: true

require "json"

module OpenRouter
  class StructuredOutputError < Error; end

  class Response
    attr_reader :raw_response, :response_format

    def initialize(raw_response, response_format: nil)
      @raw_response = raw_response.is_a?(Hash) ? raw_response.with_indifferent_access : {}
      @response_format = response_format
    end

    # Delegate common hash methods to raw_response for backward compatibility
    def [](key)
      @raw_response[key]
    end

    def dig(*keys)
      @raw_response.dig(*keys)
    end

    def fetch(key, default = nil)
      @raw_response.fetch(key, default)
    end

    def key?(key)
      @raw_response.key?(key)
    end

    def to_h
      @raw_response.to_h
    end

    def to_json(*args)
      @raw_response.to_json(*args)
    end

    # Tool calling methods
    def tool_calls
      @tool_calls ||= parse_tool_calls
    end

    def has_tool_calls?
      !tool_calls.empty?
    end

    # Convert response to message format for conversation continuation
    def to_message
      if has_tool_calls?
        {
          role: "assistant",
          content:,
          tool_calls: raw_tool_calls
        }
      else
        {
          role: "assistant",
          content:
        }
      end
    end

    # Structured output methods
    def structured_output
      @structured_output ||= parse_structured_output
    end

    def valid_structured_output?
      return true unless structured_output_expected?
      return true unless validation_available?

      schema_obj = extract_schema_from_response_format
      return true unless schema_obj

      schema_obj.validate(structured_output)
    end

    def validation_errors
      return [] unless structured_output_expected?
      return [] unless validation_available?

      schema_obj = extract_schema_from_response_format
      return [] unless schema_obj

      schema_obj.validation_errors(structured_output)
    end

    # Content accessors
    def content
      choices.first&.dig("message", "content")
    end

    def choices
      @raw_response["choices"] || []
    end

    def usage
      @raw_response["usage"]
    end

    def id
      @raw_response["id"]
    end

    def model
      @raw_response["model"]
    end

    def created
      @raw_response["created"]
    end

    def object
      @raw_response["object"]
    end

    # Convenience method to check if response has content
    def has_content?
      !content.nil? && !content.empty?
    end

    # Convenience method to check if response indicates an error
    def error?
      @raw_response.key?("error")
    end

    def error_message
      @raw_response.dig("error", "message")
    end

    private

    def parse_tool_calls
      tool_calls_data = choices.first&.dig("message", "tool_calls")
      return [] unless tool_calls_data.is_a?(Array)

      tool_calls_data.map { |tc| ToolCall.new(tc) }
    rescue StandardError => e
      raise ToolCallError, "Failed to parse tool calls: #{e.message}"
    end

    def raw_tool_calls
      choices.first&.dig("message", "tool_calls") || []
    end

    def parse_structured_output
      return nil unless structured_output_expected?
      return nil unless has_content?

      begin
        JSON.parse(content)
      rescue JSON::ParserError => e
        raise StructuredOutputError, "Failed to parse structured output: #{e.message}"
      end
    end

    def structured_output_expected?
      return false unless @response_format

      if @response_format.is_a?(Schema)
        true
      elsif @response_format.is_a?(Hash) && @response_format[:type] == "json_schema"
        true
      else
        false
      end
    end

    def validation_available?
      defined?(JSON::Validator)
    end

    def extract_schema_from_response_format
      case @response_format
      when Schema
        @response_format
      when Hash
        schema_def = @response_format[:json_schema]
        if schema_def.is_a?(Schema)
          schema_def
        elsif schema_def.is_a?(Hash) && schema_def[:schema]
          # Create a temporary schema object for validation
          Schema.new(
            schema_def[:name] || "response",
            schema_def[:schema],
            strict: schema_def[:strict] || true
          )
        end
      end
    end
  end
end
