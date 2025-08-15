# frozen_string_literal: true

require 'vcr'
require 'webmock/rspec'

# Load VCR configuration
require_relative 'support/vcr'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on Module and main
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Configure VCR
  config.around(:each, :vcr) do |example|
    name = example.metadata[:vcr][:cassette_name] || example.description
    VCR.use_cassette(name, example.metadata[:vcr]) do
      example.run
    end
  end
end