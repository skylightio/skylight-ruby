require "spec_helper"

enable = false
begin
  require "sidekiq/testing"
  enable = true
rescue LoadError
  puts "[INFO] Skipping Sidekiq unit specs"
end

if enable
  module Skylight::Core
    describe "Sidekiq" do
      after :each do
        ::Sidekiq.server_middleware.clear
      end

      it "adds server middleware" do
        # Sidekiq checks this internally
        allow(::Sidekiq).to receive(:server?).and_return(true)

        instrumentable = double(debug: nil)
        Skylight::Core::Sidekiq.add_middleware(instrumentable)

        middleware = double()
        expect(Skylight::Core::Sidekiq::ServerMiddleware).to \
          receive(:new).and_return(middleware)

        # Force the Sidekiq Middleware to get built
        ::Sidekiq.server_middleware.retrieve
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

          class ::MyWorker
            include ::Sidekiq::Worker

            def perform
              TestNamespace.instrument category: "app.inside" do
                TestNamespace.instrument category: "app.zomg" do
                  # nothing
                  sleep 0.1
                end
                sleep 0.1
              end
            end
          end

          @trace = nil
          TestNamespace.mock!(enable_sidekiq: true) do |trace|
            @trace = trace
          end
        end

        after :each do
          TestNamespace.stop!

          ::Sidekiq::Testing.disable!
          ::Sidekiq.server_middleware.clear

          # Clean slate
          Object.send(:remove_const, :MyWorker)
        end

        it "works" do
          MyWorker.perform_async

          expect(@trace.endpoint).to eq("MyWorker<sk-segment>default</sk-segment>")
          expect(@trace.mock_spans.map{|s| s[:cat]}).to eq(["app.sidekiq.worker", "app.inside", "app.zomg"])
          expect(@trace.mock_spans[0][:title]).to eq("MyWorker")
        end
      end
    end
  end
end
