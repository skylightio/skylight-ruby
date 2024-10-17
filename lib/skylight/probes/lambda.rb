# frozen_string_literal: true

module Skylight
  module Probes
    module Lambda 
      class Probe
        def install
          if defined?(::AwsLambdaRuntimeInterfaceClient::LambdaRunner)
            ::AwsLambdaRuntimeInterfaceClient::LambdaRunner.prepend(Instrumentation)
          end
        end
      end

      module Instrumentation
        AWS_LAMBDA_FUNCTION_NAME = "AWS_LAMBDA_FUNCTION_NAME"

        def run_user_code(request)
          Skylight.trace(sk_lambda_function_name, "other", sk_lambda_function_arn(request)) do
            super
          end
        ensure
          Skylight.instrumenter&.native_flush
        end

        private

        def sk_lambda_function_name
          ENV.fetch(AWS_LAMBDA_FUNCTION_NAME, "<unknown>")
        end

        def sk_lambda_function_arn(request)
          request["Lambda-Runtime-Invoked-Function-Arn"]
        rescue StandardError
          nil
        end
      end
    end

    register(:lambda, "AwsLambdaRuntimeInterfaceClient::LambdaRunner", "aws_lambda_ric", Lambda::Probe.new)
  end
end
