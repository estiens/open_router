# frozen_string_literal: true

require "json"

module OpenRouter
  class ToolCallError < Error; end

  class ToolCall
    attr_reader :id, :type, :function_name, :arguments_string

    def initialize(tool_call_data)
      @id = tool_call_data["id"]
      @type = tool_call_data["type"]

      raise ToolCallError, "Invalid tool call data: missing function" unless tool_call_data["function"]

        @function_name = tool_call_data["function"]["name"]
        @arguments_string = tool_call_data["function"]["arguments"]
    end

    # Parse the arguments JSON string into a Ruby hash
    def arguments
      @arguments ||= begin
        JSON.parse(@arguments_string)
      rescue JSON::ParserError => e
        raise ToolCallError, "Failed to parse tool call arguments: #{e.message}"
      end
    end

    # Get the function name (alias for consistency)
    def name
      @function_name
    end

    # Execute the tool call with a provided block
    # The block should accept (name, arguments) and return the result
    def execute(&block)
      raise ArgumentError, "Block required for tool execution" unless block_given?

      result = block.call(@function_name, arguments)
      ToolResult.new(self, result)
    end

    # Convert this tool call to a message format for conversation continuation
    def to_message
      {
        role: "assistant",
        content: nil,
        tool_calls: [
          {
            id: @id,
            type: @type,
            function: {
              name: @function_name,
              arguments: @arguments_string
            }
          }
        ]
      }
    end

    # Convert a tool result to a tool message for the conversation
    def to_result_message(result)
      {
        role: "tool",
        tool_call_id: @id,
        name: @function_name,
        content: result.is_a?(String) ? result : result.to_json
      }
    end

    def to_h
      {
        id: @id,
        type: @type,
        function: {
          name: @function_name,
          arguments: @arguments_string
        }
      }
    end

    def to_json(*args)
      to_h.to_json(*args)
    end
  end

  # Represents the result of executing a tool call
  class ToolResult
    attr_reader :tool_call, :result, :error

    def initialize(tool_call, result = nil, error = nil)
      @tool_call = tool_call
      @result = result
      @error = error
    end

    def success?
      @error.nil?
    end

    def failure?
      !success?
    end

    # Convert to message format for conversation continuation
    def to_message
      @tool_call.to_result_message(@error || @result)
    end

    # Create a failed result
    def self.failure(tool_call, error)
      new(tool_call, nil, error)
    end

    # Create a successful result
    def self.success(tool_call, result)
      new(tool_call, result, nil)
    end
  end
end
