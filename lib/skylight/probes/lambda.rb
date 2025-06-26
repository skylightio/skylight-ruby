# frozen_string_literal: true

module Skylight
  module Probes
    module Lambda
      AWS_LAMBDA_FUNCTION_NAME = "AWS_LAMBDA_FUNCTION_NAME"

      module Common
        private

        def sk_lambda_function_name
          ENV.fetch(AWS_LAMBDA_FUNCTION_NAME, "<unknown>")
        end
      end

      # NOTE: there are two modalities to probing the lambda wrappers:
      # - The default runtime is implemented as a plain set of nested loops; LambdaHandler is a top-level constant
      #   in this context.
      # - AWS also publishes the aws_lambda_ric gem as an alternate Dockerfile entrypoint; this runs largely
      #   the same code, but encapsulated in the LambdaRunner.
      #
      # The `run_user_code` is by all measures a better method to probe, as it includes the time spent to deliver
      # the response back to the lambda server, and we can flush the internal buffer here without affecting response time.
      module Runner
        class Probe
          def install
            if defined?(::AwsLambdaRuntimeInterfaceClient::LambdaRunner)
              ::AwsLambdaRuntimeInterfaceClient::LambdaRunner.prepend(Instrumentation)
            end
          end
        end

        module Instrumentation
          def run_user_code(request)
            Skylight.trace(sk_lambda_function_name, "other", "lambda handler") { super }
          ensure
            Skylight.instrumenter&.native_flush
          end

          include Common
        end
      end

      module Handler
        class Probe
          def install
            LambdaHandler.prepend(Instrumentation) if defined?(LambdaHandler)
          end
        end

        module Instrumentation
          def call_handler(request:, **)
            if Skylight.trace
              Skylight.instrument(sk_instrument_opts(request)) { super }
            else
              Skylight.trace(sk_lambda_function_name, "other", "lambda handler") do
                Skylight.instrument(sk_instrument_opts(request)) { super }
              end
            end
          end

          include Common

          private

          def sk_instrument_opts(request)
            {
              category: "app.lambda.handler",
              title: sk_handler_method_name,
              description: sk_lambda_function_arn(request)
            }
          end

          def sk_handler_method_name
            [@handler_file_name, @handler_class, @handler_method_name].compact.join(".")
          end

          def sk_lambda_function_arn(request)
            request["Lambda-Runtime-Invoked-Function-Arn"]
          rescue StandardError
            nil
          end
        end
      end
    end

    register(
      :lambda_runner,
      "AwsLambdaRuntimeInterfaceClient::LambdaRunner",
      "aws_lambda_ric",
      Lambda::Runner::Probe.new
    )

    # NOTE: this require hook is unlikely to be invoked; the actual default lambda runtime loads this file
    # via a require_relative.
    register(:lambda_handler, "LambdaHandler", "lambda_handler", Lambda::Handler::Probe.new)
  end
end
