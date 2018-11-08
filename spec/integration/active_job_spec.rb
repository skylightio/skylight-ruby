require 'spec_helper'

enable = false
begin
  require 'skylight/core/probes/active_job'
  require 'active_job/base'
  require 'active_job/test_helper'
  require 'skylight/railtie'
  enable = true
rescue LoadError
  puts '[INFO] Skipping active_job integration specs'
end

if enable
  class SkTestJob < ActiveJob::Base
    class Exception < ::Exception
    end

    def perform(error_key = nil)
      Skylight.instrument category: 'app.inside' do
        Skylight.instrument category: 'app.zomg' do
          # nothing
          sleep 0.1

          maybe_raise(error_key)
        end

        Skylight.instrument(category: 'app.after_zomg') { sleep 0.1 }
      end
    end

    private

    def maybe_raise(key)
      return unless key
      err = {
        'runtime_error' => RuntimeError,
        'exception' => Exception
      }[key]

      raise err if err
    end
  end

  describe 'ActiveJob integration', :http, :agent do
    around do |ex|
      stub_config_validation
      stub_session_request
      set_agent_env do
        Skylight.start!
        ex.call
        Skylight.stop!
      end
    end

    include ActiveJob::TestHelper
    # ActiveJob::Base.queue_adapter = :test

    specify do
      4.times do |n|
        SkTestJob.perform_later(n)
      end

      server.wait(count: 1)
      expect(server.reports).to be_present
      endpoint = server.reports[0].endpoints[0]
      traces = endpoint.traces
      uniq_spans = traces.map { |trace| trace.filtered_spans.map { |span| span.event.category } }.uniq
      expect(traces.count).to eq(4)
      expect(uniq_spans).to eq(
        [["app.job.execute", "app.job.perform", "app.inside", "app.zomg", "app.after_zomg"]]
      )
      expect(endpoint.name).to eq('SkTestJob<sk-segment>default</sk-segment>')
    end

    context 'error handling' do
      it 'assigns failed jobs to the error queue' do
        begin
          SkTestJob.perform_later('runtime_error')
        rescue RuntimeError
        end

        server.wait(count: 1)
        expect(server.reports).to be_present
        endpoint = server.reports[0].endpoints[0]
        traces = endpoint.traces
        uniq_spans = traces.map { |trace| trace.filtered_spans.map { |span| span.event.category } }.uniq
        expect(traces.count).to eq(1)
        expect(uniq_spans).to eq(
          [["app.job.execute", "app.job.perform", "app.inside", "app.zomg"]]
        )
        expect(endpoint.name).to eq('SkTestJob<sk-segment>error</sk-segment>')
      end

      it 'assigns jobs that raise exceptions to the error queue' do
        begin
          SkTestJob.perform_later('exception')
        rescue SkTestJob::Exception
        end

        server.wait(count: 1)
        expect(server.reports).to be_present
        endpoint = server.reports[0].endpoints[0]
        traces = endpoint.traces
        uniq_spans = traces.map { |trace| trace.filtered_spans.map { |span| span.event.category } }.uniq
        expect(traces.count).to eq(1)
        expect(uniq_spans).to eq(
          [["app.job.execute", "app.job.perform", "app.inside", "app.zomg"]]
        )
        expect(endpoint.name).to eq('SkTestJob<sk-segment>error</sk-segment>')
      end
    end
  end
end
