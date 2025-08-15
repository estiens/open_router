# frozen_string_literal: true

# Performance tests to add

RSpec.describe "Performance characteristics" do
  before do
    fixture_data = JSON.parse(File.read(File.join(__dir__, "fixtures", "openrouter_models_sample.json")))
    allow(OpenRouter::ModelRegistry).to receive(:fetch_models_from_api).and_return(fixture_data)
    OpenRouter::ModelRegistry.clear_cache!
  end

  describe "ModelRegistry performance" do
    it "caches processed models to avoid repeated computation" do
      # First call processes raw data
      start_time = Time.now
      OpenRouter::ModelRegistry.all_models
      first_call_time = Time.now - start_time

      # Second call should use cached processed data
      start_time = Time.now
      OpenRouter::ModelRegistry.all_models
      second_call_time = Time.now - start_time

      # Second call should be significantly faster
      expect(second_call_time).to be < (first_call_time * 0.1)
    end

    it "performs model searches efficiently" do
      # Warm up cache
      OpenRouter::ModelRegistry.all_models

      # Measure search performance
      start_time = Time.now

      100.times do
        OpenRouter::ModelRegistry.find_best_model(
          capabilities: [:function_calling],
          max_input_cost: 0.01
        )
      end

      elapsed = Time.now - start_time

      # Should handle 100 searches quickly
      expect(elapsed).to be < 0.1
      puts "100 model searches took: #{elapsed}s (#{elapsed / 100 * 1000}ms per search)"
    end
  end

  describe "ModelSelector performance" do
    it "handles complex chaining without performance degradation" do
      base_time = Benchmark.realtime do
        OpenRouter::ModelSelector.new.choose
      end

      complex_time = Benchmark.realtime do
        OpenRouter::ModelSelector.new
                                 .optimize_for(:cost)
                                 .require(:function_calling, :vision, :structured_outputs)
                                 .within_budget(max_cost: 0.05, max_output_cost: 0.10)
                                 .min_context(50_000)
                                 .prefer_providers("anthropic", "openai")
                                 .avoid_patterns("*-free", "*-preview")
                                 .newer_than(Date.new(2023, 1, 1))
                                 .choose
      end

      # Complex query shouldn't be dramatically slower
      expect(complex_time).to be < (base_time * 5)
      puts "Base query: #{base_time}s, Complex query: #{complex_time}s"
    end
  end
end
