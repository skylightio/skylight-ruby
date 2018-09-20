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
    def perform(arg)
      sleep(0.01) * arg
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
      42.times do |n|
        SkTestJob.perform_later(n)
      end

      server.wait(count: 1)
      expect(server.reports).to be_present
      endpoint = server.reports[0].endpoints[0]
      traces = endpoint.traces
      uniq_spans = traces.map { |trace| trace.filtered_spans.map { |span| span.event.category } }.uniq
      expect(traces.count).to eq(42)
      expect(uniq_spans).to eq([%w[app.job.execute app.job.perform]])
      expect(endpoint.name).to eq('SkTestJob<sk-segment>default</sk-segment>')
    end
  end
end
