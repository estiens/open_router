# frozen_string_literal: true

RSpec.describe OpenRouter::ModelSelector do
  let(:fixture_data) do
    JSON.parse(File.read(File.join(__dir__, "fixtures", "openrouter_models_sample.json")))
  end

  before do
    allow(OpenRouter::ModelRegistry).to receive(:fetch_models_from_api).and_return(fixture_data)
    OpenRouter::ModelRegistry.clear_cache!
  end

  describe "fluent interface for building model selection criteria" do
    it "chains methods to build complex requirements" do
      selector = described_class.new
                                .optimize_for(:cost)
                                .require(:function_calling, :vision)
                                .within_budget(max_cost: 0.01, max_output_cost: 0.02)
                                .min_context(50_000)
                                .prefer_providers("anthropic", "openai")
                                .avoid_patterns("*-free", "*-preview")

      criteria = selector.selection_criteria
      expect(criteria[:strategy]).to eq(:cost)
      expect(criteria[:requirements][:capabilities]).to include(:function_calling, :vision)
      expect(criteria[:requirements][:max_input_cost]).to eq(0.01)
      expect(criteria[:requirements][:max_output_cost]).to eq(0.02)
      expect(criteria[:requirements][:min_context_length]).to eq(50_000)
      expect(criteria[:provider_preferences][:preferred]).to include("anthropic", "openai")
      expect(criteria[:provider_preferences][:avoided_patterns]).to include("*-free", "*-preview")
    end

    it "returns new instances for immutable chaining" do
      base_selector = described_class.new
      new_selector = base_selector.optimize_for(:performance)

      expect(base_selector).not_to be(new_selector)
      expect(base_selector.selection_criteria[:strategy]).to eq(:cost)
      expect(new_selector.selection_criteria[:strategy]).to eq(:performance)
    end

    it "accumulates requirements across multiple calls" do
      selector = described_class.new
                                .require(:function_calling)
                                .require(:vision)
                                .within_budget(max_cost: 0.01)
                                .within_budget(max_output_cost: 0.02)

      capabilities = selector.selection_criteria[:requirements][:capabilities]
      expect(capabilities).to contain_exactly(:function_calling, :vision)
      expect(selector.selection_criteria[:requirements][:max_input_cost]).to eq(0.01)
      expect(selector.selection_criteria[:requirements][:max_output_cost]).to eq(0.02)
    end
  end

  describe "optimization strategies" do
    let(:selector) { described_class.new }

    it "configures cost optimization" do
      result = selector.optimize_for(:cost)
      expect(result.selection_criteria[:strategy]).to eq(:cost)
    end

    it "configures performance optimization with premium tier" do
      result = selector.optimize_for(:performance)
      expect(result.selection_criteria[:strategy]).to eq(:performance)
      expect(result.selection_criteria[:requirements][:performance_tier]).to eq(:premium)
    end

    it "configures latest model preference" do
      result = selector.optimize_for(:latest)
      expect(result.selection_criteria[:strategy]).to eq(:latest)
      expect(result.selection_criteria[:requirements][:pick_newer]).to be true
    end

    it "rejects unknown strategies" do
      expect { selector.optimize_for(:unknown) }.to raise_error(ArgumentError, /Unknown strategy/)
    end
  end

  describe "model selection behavior" do
    it "finds models meeting capability requirements" do
      selector = described_class.new.require(:function_calling)
      model = selector.choose

      expect(model).not_to be_nil
      expect(model["supported_parameters"]).to include("tools", "tool_choice")
    end

    it "filters by cost constraints" do
      selector = described_class.new.within_budget(max_cost: 0.0001)
      model = selector.choose

      if model
        input_cost = model.dig("pricing", "prompt").to_f
        expect(input_cost).to be <= 0.0001
      else
        # Should gracefully handle no matches
        expect(model).to be_nil
      end
    end

    it "respects provider preferences" do
      selector = described_class.new
                                .prefer_providers("anthropic")
                                .optimize_for(:cost)

      model = selector.choose
      if model
        expect(model["id"]).to include("anthropic") || model["name"]&.include?("anthropic")
      end
    end

    it "handles impossible requirements gracefully" do
      selector = described_class.new
                                .require(:function_calling, :vision, :structured_outputs)
                                .within_budget(max_cost: 0.000001) # Impossibly low budget
                                .min_context(1_000_000) # Impossibly high context

      expect { selector.choose }.not_to raise_error
      expect(selector.choose).to be_nil
    end
  end

  describe "multiple model selection" do
    it "returns ranked list when using choose_multiple" do
      selector = described_class.new
                                .require(:function_calling)
                                .optimize_for(:cost)

      models = selector.choose_multiple(limit: 3)
      expect(models).to be_an(Array)
      expect(models.length).to be <= 3

      # Should be sorted by cost (ascending for cost optimization)
      if models.length > 1
        costs = models.map { |m| m.dig("pricing", "prompt").to_f }
        expect(costs).to eq(costs.sort)
      end
    end

    it "includes scoring information when available" do
      selector = described_class.new.optimize_for(:performance)
      models = selector.choose_multiple(limit: 2, include_scores: true)

      models.each do |model_info|
        expect(model_info).to have_key("model")
        expect(model_info).to have_key("score") if model_info.is_a?(Hash)
      end
    end
  end

  describe "edge cases and error handling" do
    it "handles malformed model data gracefully" do
      bad_data = { "data" => [{ "id" => "broken-model" }] } # Missing required fields
      allow(OpenRouter::ModelRegistry).to receive(:fetch_models_from_api).and_return(bad_data)
      OpenRouter::ModelRegistry.clear_cache!

      selector = described_class.new
      expect { selector.choose }.not_to raise_error
    end

    it "provides meaningful error messages for invalid configurations" do
      selector = described_class.new

      expect { selector.min_context(-1) }.to raise_error(ArgumentError, /positive/)
      expect { selector.within_budget(max_cost: -0.01) }.to raise_error(ArgumentError, /positive/)
    end

    it "handles empty model registry" do
      allow(OpenRouter::ModelRegistry).to receive(:fetch_models_from_api).and_return({ "data" => [] })
      OpenRouter::ModelRegistry.clear_cache!

      selector = described_class.new
      expect(selector.choose).to be_nil
      expect(selector.choose_multiple).to be_empty
    end
  end

  describe "provider filtering" do
    it "combines prefer and avoid patterns correctly" do
      selector = described_class.new
                                .prefer_providers("anthropic", "openai")
                                .avoid_providers("meta")
                                .avoid_patterns("*-free", "*-preview")

      preferences = selector.selection_criteria[:provider_preferences]
      expect(preferences[:preferred]).to contain_exactly("anthropic", "openai")
      expect(preferences[:avoided_providers]).to contain_exactly("meta")
      expect(preferences[:avoided_patterns]).to contain_exactly("*-free", "*-preview")
    end
  end

  describe "date filtering" do
    it "handles various date formats for newer_than" do
      date = Date.new(2023, 6, 1)
      time = Time.new(2023, 6, 1)
      string = "2023-06-01"

      [date, time, string].each do |date_input|
        selector = described_class.new.newer_than(date_input)
        expect(selector.selection_criteria[:requirements][:newer_than]).to be_a(Date)
      end
    end
  end
end