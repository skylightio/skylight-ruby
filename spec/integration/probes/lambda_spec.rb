# frozen_string_literal: true

require "spec_helper"
require "skylight/probes/lambda"

begin
  require "aws_lambda_ric"
rescue LoadError
end

if defined?(::AwsLambdaRuntimeInterfaceClient::LambdaRunner)
  class LambdaSkylightTest
    def self.lambda_handler(*_args)
      { ok: true }
    end
  end

  describe "Lambda integration", :lambda_probe, :agent do
    before do
      Skylight.mock!(enable_source_locations: true) { |trace| @current_trace = trace }
      ENV[Skylight::Probes::Lambda::Instrumentation::AWS_LAMBDA_FUNCTION_NAME] ||= "lambda-integration-test"
    end

    specify do
      runner = ::AwsLambdaRuntimeInterfaceClient::LambdaRunner.new("", "skylight-test-ua")
      lambda_server = runner.instance_variable_get(:@lambda_server)
      responses = [] 
      allow(lambda_server).to receive(:send_response) {|*args| responses << args }
      runner.instance_variable_set(:@lambda_handler, 
LambdaHandler.new(env_handler: "this.LambdaSkylightTest.lambda_handler"))

      raw_request = double(body: "{\"foo\": true}")
      allow(raw_request).to receive(:[]).with("Content-Type") { "application/json" }
      allow(raw_request).to receive(:[]).with("Lambda-Runtime-Deadline-Ms") { 10000 }
      allow(raw_request).to receive(:[]).with("Lambda-Runtime-Aws-Request-Id") { "request-id" }
      allow(raw_request).to receive(:[]).with("Lambda-Runtime-Invoked-Function-Arn") { "a:b:c:d" }
      allow(raw_request).to receive(:[]) { nil }

      request = AwsLambda::Marshaller.marshall_request(raw_request)
      req = ::AwsLambdaRuntimeInterfaceClient::LambdaInvocationRequest.new("request-id", raw_request, request, 
"x-amzn-trace-id")
      runner.send(:run_user_code, req)

      expect(responses.length).to eq(1)
      expect(@current_trace.endpoint).to eq("lambda-integration-test")
    end
  end
end
