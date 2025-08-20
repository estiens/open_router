# frozen_string_literal: true

require "active_support/core_ext/object/blank"
require "active_support/core_ext/hash/indifferent_access"

require_relative "http"

module OpenRouter
  class ServerError < StandardError; end

  class Client
    include OpenRouter::HTTP

    # Initializes the client with optional configurations.
    def initialize(access_token: nil, request_timeout: nil, uri_base: nil, extra_headers: {})
      OpenRouter.configuration.access_token = access_token if access_token
      OpenRouter.configuration.request_timeout = request_timeout if request_timeout
      OpenRouter.configuration.uri_base = uri_base if uri_base
      OpenRouter.configuration.extra_headers = extra_headers if extra_headers.any?
      yield(OpenRouter.configuration) if block_given?

      # Instance-level tracking of capability warnings to avoid memory leaks
      @capability_warnings_shown = Set.new
    end

    def configuration
      OpenRouter.configuration
    end

    # Performs a chat completion request to the OpenRouter API.
    # @param messages [Array<Hash>] Array of message hashes with role and content, like [{role: "user", content: "What is the meaning of life?"}]
    # @param model [String|Array] Model identifier, or array of model identifiers if you want to fallback to the next model in case of failure
    # @param providers [Array<String>] Optional array of provider identifiers, ordered by priority
    # @param transforms [Array<String>] Optional array of strings that tell OpenRouter to apply a series of transformations to the prompt before sending it to the model. Transformations are applied in-order
    # @param tools [Array<Tool>] Optional array of Tool objects or tool definition hashes for function calling
    # @param tool_choice [String|Hash] Optional tool choice: "auto", "none", "required", or specific tool selection
    # @param response_format [Hash] Optional response format for structured outputs
    # @param extras [Hash] Optional hash of model-specific parameters to send to the OpenRouter API
    # @param stream [Proc, nil] Optional callable object for streaming
    # @return [Response] The completion response wrapped in a Response object.
    def complete(messages, model: "openrouter/auto", providers: [], transforms: [], tools: [], tool_choice: nil,
                 response_format: nil, force_structured_output: nil, extras: {}, stream: nil)
      parameters = { messages: messages.dup }
      if model.is_a?(String)
        parameters[:model] = model
      elsif model.is_a?(Array)
        parameters[:models] = model
        parameters[:route] = "fallback"
      end
      parameters[:provider] = { order: providers } if providers.any?
      parameters[:transforms] = transforms if transforms.any?

      # Add tool calling support
      if tools.any?
        warn_if_unsupported(model, :function_calling, "tool calling")
        parameters[:tools] = serialize_tools(tools)
        parameters[:tool_choice] = tool_choice if tool_choice
      end

      # Add structured output support
      forced_extraction = false
      if response_format
        # Auto-detect if we should force based on model capabilities
        if force_structured_output.nil?
          if model.is_a?(String) && model != "openrouter/auto" && !ModelRegistry.has_capability?(model, :structured_outputs) && configuration.auto_force_on_unsupported_models
            warn "[OpenRouter] Model '#{model}' doesn't support native structured outputs. Automatically using forced extraction mode."
            force_structured_output = true
          else
            force_structured_output = false
          end
        end

        if force_structured_output
          # Forced path - inject instructions, DON'T send response_format to API
          # In strict mode, still validate to ensure user is aware of capability limits
          warn_if_unsupported(model, :structured_outputs, "structured outputs") if configuration.strict_mode
          inject_schema_instructions!(parameters[:messages], response_format)
          forced_extraction = true
        else
          # Native path - send to API, always validate capabilities
          warn_if_unsupported(model, :structured_outputs, "structured outputs")
          parameters[:response_format] = serialize_response_format(response_format)
        end
      end

      # Check for vision support if messages contain images
      warn_if_unsupported(model, :vision, "vision/image processing") if messages_contain_images?(messages)

      parameters[:stream] = stream if stream
      parameters.merge!(extras)

      begin
        raw_response = post(path: "/chat/completions", parameters:)
      rescue ConfigurationError => e
        # Convert configuration errors to server errors for consistent API
        raise ServerError, e.message
      rescue Faraday::Error => e
        # Re-raise certain errors that tests and applications might expect
        case e
        when Faraday::UnauthorizedError
          # Let UnauthorizedError bubble up for testing capability validation
          raise e
        when Faraday::BadRequestError
          error_message = e.response&.dig(:body, "error", "message") || e.message
          raise ServerError, "Bad Request: #{error_message}"
        when Faraday::ServerError
          raise ServerError, "Server Error: #{e.message}"
        else
          raise ServerError, "Network Error: #{e.message}"
        end
      end

      raise ServerError, raw_response.dig("error", "message") if raw_response.presence&.dig("error", "message").present?

      if stream.blank? && raw_response.blank?
        raise ServerError,
              "Empty response from OpenRouter. Might be worth retrying once or twice."
      end

      # Return a Response object instead of raw hash
      response = Response.new(raw_response, response_format:, forced_extraction:)

      # Always set client reference for configuration access
      response.client = self

      response
    end

    # Fetches the list of available models from the OpenRouter API.
    # @return [Array<Hash>] The list of models.
    def models
      get(path: "/models")["data"]
    end

    # Queries the generation stats for a given id.
    # @param generation_id [String] The generation id returned from a previous request.
    # @return [Hash] The stats including token counts and cost.
    def query_generation_stats(generation_id)
      response = get(path: "/generation?id=#{generation_id}")
      response["data"]
    end

    # Create a new ModelSelector for intelligent model selection
    #
    # @return [ModelSelector] A new ModelSelector instance
    # @example
    #   client = OpenRouter::Client.new
    #   model = client.select_model.optimize_for(:cost).require(:function_calling).choose
    def select_model
      ModelSelector.new
    end

    # Smart completion that automatically selects the best model based on requirements
    #
    # @param messages [Array<Hash>] Array of message hashes
    # @param requirements [Hash] Model selection requirements
    # @param optimization [Symbol] Optimization strategy (:cost, :performance, :latest, :context)
    # @param extras [Hash] Additional parameters for the completion request
    # @return [Response] The completion response
    # @raise [ModelSelectionError] If no suitable model is found
    #
    # @example
    #   response = client.smart_complete(
    #     messages: [{ role: "user", content: "Analyze this data" }],
    #     requirements: { capabilities: [:function_calling], max_input_cost: 0.01 },
    #     optimization: :cost
    #   )
    def smart_complete(messages, requirements: {}, optimization: :cost, **extras)
      selector = ModelSelector.new.optimize_for(optimization)

      # Apply requirements using fluent interface
      selector = selector.require(*requirements[:capabilities]) if requirements[:capabilities]

      if requirements[:max_cost] || requirements[:max_input_cost]
        cost_opts = {}
        cost_opts[:max_cost] = requirements[:max_cost] || requirements[:max_input_cost]
        cost_opts[:max_output_cost] = requirements[:max_output_cost] if requirements[:max_output_cost]
        selector = selector.within_budget(**cost_opts)
      end

      selector = selector.min_context(requirements[:min_context_length]) if requirements[:min_context_length]

      if requirements[:providers]
        case requirements[:providers]
        when Hash
          selector = selector.prefer_providers(*requirements[:providers][:prefer]) if requirements[:providers][:prefer]
          if requirements[:providers][:require]
            selector = selector.require_providers(*requirements[:providers][:require])
          end
          selector = selector.avoid_providers(*requirements[:providers][:avoid]) if requirements[:providers][:avoid]
        when Array
          selector = selector.prefer_providers(*requirements[:providers])
        end
      end

      # Select the best model
      model = selector.choose
      raise ModelSelectionError, "No model found matching requirements: #{requirements}" unless model

      # Perform the completion with the selected model
      complete(messages, model:, **extras)
    end

    # Smart completion with automatic fallback to alternative models
    #
    # @param messages [Array<Hash>] Array of message hashes
    # @param requirements [Hash] Model selection requirements
    # @param optimization [Symbol] Optimization strategy
    # @param max_retries [Integer] Maximum number of fallback attempts
    # @param extras [Hash] Additional parameters for the completion request
    # @return [Response] The completion response
    # @raise [ModelSelectionError] If all fallback attempts fail
    #
    # @example
    #   response = client.smart_complete_with_fallback(
    #     messages: [{ role: "user", content: "Hello" }],
    #     requirements: { capabilities: [:function_calling] },
    #     max_retries: 3
    #   )
    def smart_complete_with_fallback(messages, requirements: {}, optimization: :cost, max_retries: 3, **extras)
      selector = ModelSelector.new.optimize_for(optimization)

      # Apply requirements (same logic as smart_complete)
      selector = selector.require(*requirements[:capabilities]) if requirements[:capabilities]

      if requirements[:max_cost] || requirements[:max_input_cost]
        cost_opts = {}
        cost_opts[:max_cost] = requirements[:max_cost] || requirements[:max_input_cost]
        cost_opts[:max_output_cost] = requirements[:max_output_cost] if requirements[:max_output_cost]
        selector = selector.within_budget(**cost_opts)
      end

      selector = selector.min_context(requirements[:min_context_length]) if requirements[:min_context_length]

      if requirements[:providers]
        case requirements[:providers]
        when Hash
          selector = selector.prefer_providers(*requirements[:providers][:prefer]) if requirements[:providers][:prefer]
          if requirements[:providers][:require]
            selector = selector.require_providers(*requirements[:providers][:require])
          end
          selector = selector.avoid_providers(*requirements[:providers][:avoid]) if requirements[:providers][:avoid]
        when Array
          selector = selector.prefer_providers(*requirements[:providers])
        end
      end

      # Get fallback models
      fallback_models = selector.choose_with_fallbacks(limit: max_retries + 1)
      raise ModelSelectionError, "No models found matching requirements: #{requirements}" if fallback_models.empty?

      last_error = nil

      fallback_models.each do |model|
        return complete(messages, model:, **extras)
      rescue StandardError => e
        last_error = e
        # Continue to next model in fallback list
      end

      # If we get here, all models failed
      raise ModelSelectionError, "All fallback models failed. Last error: #{last_error&.message}"
    end

    private

    # Warn if a model is being used with an unsupported capability
    def warn_if_unsupported(model, capability, feature_name)
      # Skip warnings for array models (fallbacks) or auto-selection
      return if model.is_a?(Array) || model == "openrouter/auto"

      return if ModelRegistry.has_capability?(model, capability)

      if configuration.strict_mode
        raise CapabilityError,
              "Model '#{model}' does not support #{feature_name} (missing :#{capability} capability). Enable non-strict mode to allow this request."
      end

      warning_key = "#{model}:#{capability}"
      return if @capability_warnings_shown.include?(warning_key)

      warn "[OpenRouter Warning] Model '#{model}' may not support #{feature_name} (missing :#{capability} capability). The request will still be attempted."
      @capability_warnings_shown << warning_key
    end

    # Check if messages contain image content
    def messages_contain_images?(messages)
      messages.any? do |msg|
        content = msg[:content] || msg["content"]
        if content.is_a?(Array)
          content.any? { |part| part.is_a?(Hash) && (part[:type] == "image_url" || part["type"] == "image_url") }
        else
          false
        end
      end
    end

    # Serialize tools to the format expected by OpenRouter API
    def serialize_tools(tools)
      tools.map do |tool|
        case tool
        when Tool
          tool.to_h
        when Hash
          tool
        else
          raise ArgumentError, "Tools must be Tool objects or hashes"
        end
      end
    end

    # Serialize response format to the format expected by OpenRouter API
    def serialize_response_format(response_format)
      case response_format
      when Hash
        if response_format[:json_schema].is_a?(Schema)
          response_format.merge(json_schema: response_format[:json_schema].to_h)
        else
          response_format
        end
      when Schema
        {
          type: "json_schema",
          json_schema: response_format.to_h
        }
      else
        response_format
      end
    end

    # Inject schema instructions into messages for forced structured output
    def inject_schema_instructions!(messages, response_format)
      schema = extract_schema(response_format)
      return unless schema

      instruction_content = if schema.respond_to?(:get_format_instructions)
                              schema.get_format_instructions
                            else
                              build_schema_instruction(schema)
                            end

      # Add as system message
      messages << { role: "system", content: instruction_content }
    end

    # Extract schema from response_format
    def extract_schema(response_format)
      case response_format
      when Schema
        response_format
      when Hash
        # Handle both Schema objects and raw hash schemas
        if response_format[:json_schema].is_a?(Schema)
          response_format[:json_schema]
        elsif response_format[:json_schema].is_a?(Hash)
          response_format[:json_schema]
        else
          response_format
        end
      end
    end

    # Build schema instruction when schema doesn't have get_format_instructions
    def build_schema_instruction(schema)
      schema_json = schema.respond_to?(:to_h) ? schema.to_h.to_json : schema.to_json

      <<~INSTRUCTION
        You must respond with valid JSON matching this exact schema:

        ```json
        #{schema_json}
        ```

        Rules:
        - Return ONLY the JSON object, no other text
        - Ensure all required fields are present
        - Match the exact data types specified
        - Follow any format constraints (email, date, etc.)
        - Do not include trailing commas or comments
      INSTRUCTION
    end
  end
end
