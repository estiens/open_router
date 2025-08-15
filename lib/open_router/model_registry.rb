# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module OpenRouter
  class ModelRegistryError < Error; end

  class ModelRegistry
    API_BASE = "https://openrouter.ai/api/v1"
    CACHE_FILE = ".openrouter_models_cache.json"

    class << self
      # Fetch models from OpenRouter API
      def fetch_models_from_api
        uri = URI("#{API_BASE}/models")
        response = Net::HTTP.get_response(uri)

        raise ModelRegistryError, "Failed to fetch models from OpenRouter API: #{response.message}" unless response.code == "200"

        JSON.parse(response.body)
      rescue JSON::ParserError => e
        raise ModelRegistryError, "Failed to parse OpenRouter API response: #{e.message}"
      rescue StandardError => e
        raise ModelRegistryError, "Network error fetching models: #{e.message}"
      end

      # Cache models locally
      def cache_models(models_data)
        File.write(CACHE_FILE, JSON.pretty_generate(models_data))
      end

      # Load models from cache
      def load_cached_models
        return nil unless File.exist?(CACHE_FILE)

        JSON.parse(File.read(CACHE_FILE))
      rescue JSON::ParserError
        nil
      end

      # Clear local cache
      def clear_cache!
        File.delete(CACHE_FILE) if File.exist?(CACHE_FILE)
        @processed_models = nil
      end

      # Refresh models data from API
      def refresh!
        clear_cache!
        fetch_and_cache_models
      end

      # Get processed models (fetch if needed)
      def fetch_and_cache_models
        # Try cache first
        cached_data = load_cached_models

        if cached_data
          api_data = cached_data
        else
          api_data = fetch_models_from_api
          cache_models(api_data)
        end

        @processed_models = process_api_models(api_data["data"])
      end

      # Convert API model data to our internal format
      def process_api_models(api_models)
        models = {}

        api_models.each do |model_data|
          model_id = model_data["id"]

          models[model_id] = {
            name: model_data["name"],
            cost_per_1k_tokens: {
              input: model_data["pricing"]["prompt"].to_f,
              output: model_data["pricing"]["completion"].to_f
            },
            context_length: model_data["context_length"],
            capabilities: extract_capabilities(model_data),
            description: model_data["description"],
            supported_parameters: model_data["supported_parameters"] || [],
            architecture: model_data["architecture"],
            performance_tier: determine_performance_tier(model_data),
            fallbacks: determine_fallbacks(model_id, model_data),
            created_at: model_data["created"]
          }
        end

        models
      end

      # Extract capabilities from model data
      def extract_capabilities(model_data)
        capabilities = [:chat] # All models support basic chat

        # Check for function calling support
        supported_params = model_data["supported_parameters"] || []
        capabilities << :function_calling if supported_params.include?("tools") && supported_params.include?("tool_choice")

        # Check for structured output support
        capabilities << :structured_outputs if supported_params.include?("structured_outputs") || supported_params.include?("response_format")

        # Check for vision support
        architecture = model_data["architecture"] || {}
        input_modalities = architecture["input_modalities"] || []
        capabilities << :vision if input_modalities.include?("image")

        # Check for large context support
        context_length = model_data["context_length"] || 0
        capabilities << :long_context if context_length > 100_000

        capabilities
      end

      # Determine performance tier based on pricing and capabilities
      def determine_performance_tier(model_data)
        input_cost = model_data["pricing"]["prompt"].to_f

        # Higher cost generally indicates premium models
        if input_cost > 0.00001 # > $0.01 per 1k tokens
          :premium
        else
          :standard
        end
      end

      # Determine fallback models (simplified logic)
      def determine_fallbacks(_model_id, _model_data)
        # For now, return empty array - could be enhanced with smart fallback logic
        []
      end

      # Find the best model matching given requirements
      def find_best_model(requirements = {})
        candidates = models_meeting_requirements(requirements)
        return nil if candidates.empty?

        # If pick_newer is true, prefer newer models over cost
        if requirements[:pick_newer]
          candidates.max_by { |_, specs| specs[:created_at] }
        else
          # Sort by cost (cheapest first) as default strategy
          candidates.min_by { |_, specs| calculate_model_cost(specs, requirements) }
        end
      end

      # Get all models that meet requirements (without sorting)
      def models_meeting_requirements(requirements = {})
        all_models.select do |_model, specs|
          meets_requirements?(specs, requirements)
        end
      end

      # Get fallback models for a given model
      def get_fallbacks(model)
        model_info = get_model_info(model)
        model_info ? model_info[:fallbacks] || [] : []
      end

      # Check if a model exists in the registry
      def model_exists?(model)
        all_models.key?(model)
      end

      # Get detailed information about a model
      def get_model_info(model)
        all_models[model]
      end

      # Get all registered models (fetch from API if needed)
      def all_models
        @all_models ||= fetch_and_cache_models
      end

      # Calculate estimated cost for a request
      def calculate_estimated_cost(model, input_tokens: 0, output_tokens: 0)
        model_info = get_model_info(model)
        return 0 unless model_info

        input_cost = (input_tokens / 1000.0) * model_info[:cost_per_1k_tokens][:input]
        output_cost = (output_tokens / 1000.0) * model_info[:cost_per_1k_tokens][:output]

        input_cost + output_cost
      end

      private

      # Check if model specs meet the given requirements
      def meets_requirements?(specs, requirements)
        # Check capability requirements
        if requirements[:capabilities]
          required_caps = Array(requirements[:capabilities])
          return false unless required_caps.all? { |cap| specs[:capabilities].include?(cap) }
        end

        # Check cost requirements
        return false if requirements[:max_input_cost] && (specs[:cost_per_1k_tokens][:input] > requirements[:max_input_cost])

        return false if requirements[:max_output_cost] && (specs[:cost_per_1k_tokens][:output] > requirements[:max_output_cost])

        # Check context length requirements
        return false if requirements[:min_context_length] && (specs[:context_length] < requirements[:min_context_length])

        # Check performance tier requirements
        if requirements[:performance_tier]
          required_tier = requirements[:performance_tier]
          model_tier = specs[:performance_tier]

          # Premium tier can satisfy premium or standard requirements
          # Standard tier can only satisfy standard requirements
          case required_tier
          when :premium
            return false unless model_tier == :premium
          when :standard
            return false unless %i[standard premium].include?(model_tier)
          end
        end

        # Check released after date requirement
        if requirements[:released_after_date]
          required_date = requirements[:released_after_date]
          model_timestamp = specs[:created_at]

          # Convert date to timestamp if needed
          required_timestamp = case required_date
                               when Date, Time
                                 required_date.to_i
                               when Integer
                                 required_date
                               else
                                 return false
                               end

          return false if model_timestamp < required_timestamp
        end

        true
      end

      # Calculate the cost metric for sorting models
      def calculate_model_cost(specs, _requirements)
        # Simple cost calculation for sorting - could be made more sophisticated
        # For now, just use input token cost as the primary metric
        specs[:cost_per_1k_tokens][:input]
      end
    end
  end
end
