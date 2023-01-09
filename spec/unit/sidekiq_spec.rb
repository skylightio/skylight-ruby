require "spec_helper"

enable = false
begin
  require "sidekiq/testing"
  enable = true
rescue LoadError
  puts "[INFO] Skipping Sidekiq unit specs"
end

if enable
  module Skylight
    describe "Sidekiq" do
      def server_middleware
        sidekiq_7? ? ::Sidekiq.default_configuration.server_middleware : ::Sidekiq.server_middleware
      end

      def sidekiq_7?
        ::Sidekiq::VERSION =~ /\A7/
      end

      after :each do
        server_middleware.clear
      end

      it "adds server middleware" do
        # Sidekiq checks this internally
        allow(::Sidekiq).to receive(:server?).and_return(true)

        Skylight::Sidekiq.add_middleware

        middleware = double
        expect(Skylight::Sidekiq::ServerMiddleware).to receive(:new).and_return(middleware)

        # Force the Sidekiq Middleware to get built
        server_middleware.retrieve
      end

      context "instrumenting worker", :agent do
        before :each do
          ::Sidekiq::Testing.inline!

          allow(::Sidekiq).to receive(:server?).and_return(true)

          # `Sidekiq.configure_server` doesn't run in testing usually, stub it
          # out so that it does
          allow(::Sidekiq).to receive(:configure_server) do |&block|
            block.call(::Sidekiq::Testing)
          end

          my_worker =
            Class.new do
              include ::Sidekiq::Worker

              def perform
                Skylight.instrument category: "app.inside" do
                  Skylight.instrument category: "app.zomg" do
                    # nothing
                    SpecHelper.clock.skip 1
                  end
                  SpecHelper.clock.skip 1
                end
              end
            end

          stub_const("MyWorker", my_worker)

          @trace = nil
          Skylight.mock!(enable_sidekiq: true) { |trace| @trace = trace }
        end

        after :each do
          Skylight.stop!

          ::Sidekiq::Testing.disable!
          server_middleware.clear
        end

        it "works" do
          MyWorker.perform_async

          expect(@trace.endpoint).to eq("MyWorker<sk-segment>default</sk-segment>")
          expect(@trace.filter_spans.map { |s| s[:cat] }).to eq(%w[app.sidekiq.worker app.inside app.zomg])
          expect(@trace.mock_spans[0][:title]).to eq("MyWorker")
        end
      end
    end
  end
end
