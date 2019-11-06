require "spec_helper"

enable = false
begin
  # Sidekiq 4.2 checks for the Rails constant but not for whether it responds to
  # `#env`. (This is fixed in Sidekiq 5+) When we use ActionView in the
  # ActionView Probe spec, it causes the Rails constant to be defined without the
  # `#env` method. This is a hack to make it not crash.
  if defined?(Rails) && !Rails.respond_to?(:env) &&
     (spec = Gem.loaded_specs["sidekiq"]) &&
     Gem::Dependency.new("sidekiq", "~> 4.2").match?(spec)
    def Rails.env
      @_env ||= ActiveSupport::StringInquirer.new("")
    end
  end

  require "sidekiq/testing"
  enable = true
rescue LoadError
  puts "[INFO] Skipping Sidekiq unit specs"
end

if enable
  module Skylight
    describe "Sidekiq" do
      after :each do
        ::Sidekiq.server_middleware.clear
      end

      it "adds server middleware" do
        # Sidekiq checks this internally
        allow(::Sidekiq).to receive(:server?).and_return(true)

        Skylight::Sidekiq.add_middleware

        middleware = double
        expect(Skylight::Sidekiq::ServerMiddleware).to \
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
              Skylight.instrument category: "app.inside" do
                Skylight.instrument category: "app.zomg" do
                  # nothing
                  sleep 0.1
                end
                sleep 0.1
              end
            end
          end

          @trace = nil
          Skylight.mock!(enable_sidekiq: true) do |trace|
            @trace = trace
          end
        end

        after :each do
          Skylight.stop!

          ::Sidekiq::Testing.disable!
          ::Sidekiq.server_middleware.clear

          # Clean slate
          Object.send(:remove_const, :MyWorker)
        end

        it "works" do
          MyWorker.perform_async

          expect(@trace.endpoint).to eq("MyWorker<sk-segment>default</sk-segment>")
          expect(@trace.mock_spans.map { |s| s[:cat] }).to eq(["app.sidekiq.worker", "app.inside", "app.zomg"])
          expect(@trace.mock_spans[0][:title]).to eq("MyWorker")
        end
      end
    end
  end
end
