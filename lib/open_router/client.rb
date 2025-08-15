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
    def complete(messages, model: "openrouter/auto", providers: [], transforms: [], tools: [], tool_choice: nil, response_format: nil, extras: {}, stream: nil)
      parameters = { messages: }
      if model.is_a?(String)
        parameters[:model] = model
      elsif model.is_a?(Array)
        parameters[:models] = model
        parameters[:route] = "fallback"
      end
      parameters[:provider] = { provider: { order: providers } } if providers.any?
      parameters[:transforms] = transforms if transforms.any?

      # Add tool calling support
      if tools.any?
        parameters[:tools] = serialize_tools(tools)
        parameters[:tool_choice] = tool_choice if tool_choice
      end

      # Add structured output support
      parameters[:response_format] = serialize_response_format(response_format) if response_format

      parameters[:stream] = stream if stream
      parameters.merge!(extras)

      raw_response = post(path: "/chat/completions", parameters:)

      raise ServerError, raw_response.dig("error", "message") if raw_response.presence&.dig("error", "message").present?
      raise ServerError, "Empty response from OpenRouter. Might be worth retrying once or twice." if stream.blank? && raw_response.blank?

      # Return a Response object instead of raw hash
      Response.new(raw_response, response_format:)
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
          selector = selector.require_providers(*requirements[:providers][:require]) if requirements[:providers][:require]
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
          selector = selector.require_providers(*requirements[:providers][:require]) if requirements[:providers][:require]
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
  end
end
