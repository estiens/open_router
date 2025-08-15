# frozen_string_literal: true

RSpec.describe OpenRouter::HTTP do
  let(:test_client) do
    Class.new do
      include OpenRouter::HTTP

      def initialize
        @log_errors = false
      end
    end.new
  end

  before do
    OpenRouter.configure do |config|
      config.access_token = "test_token"
      config.uri_base = "https://openrouter.ai/api"
      config.api_version = "v1"
      config.request_timeout = 120
      config.extra_headers = {}
    end
  end

  describe "HTTP methods" do
    let(:mock_response) { double("response", body: { "test" => "response" }) }

    before do
      allow(test_client).to receive(:conn).and_return(double("connection"))
      allow(test_client.conn).to receive(:get).and_return(mock_response)
      allow(test_client.conn).to receive(:post).and_return(mock_response)
      allow(test_client.conn).to receive(:delete).and_return(mock_response)
    end

    describe "#get" do
      it "makes GET request with proper headers" do
        expect(test_client.conn).to receive(:get).with("https://openrouter.ai/api/v1/test")
        test_client.get(path: "test")
      end
    end

    describe "#post" do
      it "makes POST request with JSON body" do
        expect(test_client.conn).to receive(:post).with("https://openrouter.ai/api/v1/chat")
        test_client.post(path: "chat", parameters: { model: "gpt-3.5-turbo", messages: [] })
      end

      context "with streaming" do
        it "configures streaming when stream proc provided" do
          stream_proc = proc { |chunk| puts chunk }
          parameters = { model: "gpt-3.5-turbo", stream: stream_proc }

          expect(test_client.conn).to receive(:post) do |path, &block|
            req = double("request", headers: {}, body: "", options: double("options"))
            allow(req.options).to receive(:on_data=)
            expect(req.options).to receive(:on_data=)
            block.call(req)
          end

          test_client.post(path: "chat", parameters: parameters)
        end
      end
    end

    describe "#delete" do
      it "makes DELETE request with proper headers" do
        expect(test_client.conn).to receive(:delete).with("https://openrouter.ai/api/v1/models/test")
        test_client.delete(path: "models/test")
      end
    end
  end

  describe "private methods" do
    describe "#uri" do
      it "constructs proper API URI" do
        uri = test_client.send(:uri, path: "chat/completions")
        expect(uri).to eq("https://openrouter.ai/api/v1/chat/completions")
      end
    end

    describe "#headers" do
      it "includes required OpenRouter headers" do
        headers = test_client.send(:headers)
        expect(headers).to include(
          "Authorization" => "Bearer test_token",
          "Content-Type" => "application/json",
          "X-Title" => "OpenRouter Ruby Client",
          "HTTP-Referer" => "https://github.com/OlympiaAI/open_router"
        )
      end

      it "merges extra headers from configuration" do
        OpenRouter.configuration.extra_headers = { "Custom-Header" => "value" }
        headers = test_client.send(:headers)
        expect(headers["Custom-Header"]).to eq("value")
      end
    end

    describe "#to_json_stream" do
      it "parses valid JSON chunks from stream" do
        results = []
        user_proc = proc { |data| results << data }
        stream_proc = test_client.send(:to_json_stream, user_proc: user_proc)

        chunk = 'data: {"test": "value"}\n\nerror: {"error": "message"}\n\n'
        stream_proc.call(chunk, nil)

        expect(results).to eq([
          { "test" => "value" },
          { "error" => "message" }
        ])
      end

      it "ignores invalid JSON in stream" do
        results = []
        user_proc = proc { |data| results << data }
        stream_proc = test_client.send(:to_json_stream, user_proc: user_proc)

        chunk = 'data: {"valid": "json"}\n\ndata: invalid-json\n\n'
        stream_proc.call(chunk, nil)

        expect(results).to eq([{ "valid" => "json" }])
      end
    end
  end

  describe "connection configuration" do
    it "applies faraday configuration from OpenRouter config" do
      custom_config = proc { |f| f.use :instrumentation }
      OpenRouter.configure { |config| config.faraday_config = custom_config }

      expect(custom_config).to receive(:call)
      test_client.send(:conn)
    end

    it "sets proper timeout from configuration" do
      OpenRouter.configuration.request_timeout = 60
      connection = test_client.send(:conn)
      expect(connection.options[:timeout]).to eq(60)
    end
  end
end