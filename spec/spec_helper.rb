# frozen_string_literal: true

require 'open_router'
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
    vcr_options = example.metadata[:vcr]
    if vcr_options.is_a?(Hash)
      name = vcr_options.delete(:cassette_name) || example.description.downcase.gsub(/\s+/, '_')
      VCR.use_cassette(name, vcr_options) do
        example.run
      end
    else
      name = example.description.downcase.gsub(/\s+/, '_')
      VCR.use_cassette(name) do
        example.run
      end
    end
  end
end