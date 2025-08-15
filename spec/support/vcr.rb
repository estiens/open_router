# frozen_string_literal: true

require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  
  # Filter sensitive data
  config.filter_sensitive_data('<OPENROUTER_API_KEY>') { ENV['OPENROUTER_API_KEY'] }
  config.filter_sensitive_data('<ACCESS_TOKEN>') { ENV['ACCESS_TOKEN'] }
  
  # Default cassette options
  config.default_cassette_options = {
    record: :new_episodes,
    match_requests_on: [:method, :uri, :body]
  }
  
  # Allow real HTTP requests when no cassette
  config.allow_http_connections_when_no_cassette = false
  
  # Configure request matching
  config.configure_rspec_metadata!
end

# Helper method for VCR tests
def with_vcr(cassette_name, **options)
  VCR.use_cassette(cassette_name, options) do
    yield
  end
end