require 'spec_helper'
require 'skylight/core/instrumenter'

enable = false
begin
  require 'sidekiq/testing'
  enable = true
rescue LoadError
  puts "[INFO] Skipping Sidekiq integration specs"
end

if enable
  describe 'Sidekiq integration' do

    before :each do
      @original_env = ENV.to_hash
      set_agent_env
      ENV['SKYLIGHT_ENABLE_SIDEKIQ'] = 'true'

      Sidekiq::Testing.inline!

      # `Sidekiq.server?` doesn't return true in testing
      allow(::Sidekiq).to receive(:server?).and_return(true)

      # `Sidekiq.configure_server` doesn't run in testing usually, stub it
      # out so that it does
      allow(::Sidekiq).to receive(:configure_server) do |&block|
        block.call(Sidekiq::Testing)
      end

      Skylight.start!

      class ::MyWorker
        include Sidekiq::Worker

        def perform
          Skylight.instrument category: 'app.inside' do
            Skylight.instrument category: 'app.zomg' do
              # nothing
              sleep 0.1
            end
            sleep 0.1
          end
        end
      end
    end

    after :each do
      ENV.replace(@original_env)
      Skylight.stop!
      Sidekiq::Testing.disable!

      # Clean slate
      Object.send(:remove_const, :MyWorker)
    end

    context "with agent", :http, :agent do
      before :each do
        stub_config_validation
        stub_session_request
      end

      it 'successfully calls into app' do
        MyWorker.perform_async

        server.wait resource: '/report'

        batch = server.reports[0]
        expect(batch).to_not be nil
        expect(batch.endpoints.count).to eq(1)
        endpoint = batch.endpoints[0]
        expect(endpoint.name).to eq("MyWorker#perform<sk-segment>default</sk-segment>")
        expect(endpoint.traces.count).to eq(1)
        trace = endpoint.traces[0]

        names = trace.filtered_spans.map { |s| s.event.category }

        expect(names).to eq(['app.sidekiq.worker', 'app.inside', 'app.zomg'])
      end

    end
  end
end
