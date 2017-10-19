require "spec_helper"

enable = false
begin
  require "active_job"
  enable = true
rescue LoadError
  puts "[INFO] Skipping Active Job unit tests"
end

if enable
  module Skylight
    describe "ActiveJob", "enqueue_at.active_job", :agent do
      # Not enabled by default due to questionable usefulness
      require "skylight/core/normalizers/active_job/enqueue_at"

      class TestJob < ::ActiveJob::Base
      end

      it "normalizes the notification name with defaults" do
        adapter = ActiveJob::QueueAdapters::InlineAdapter.new
        job = TestJob.new

        name, title, desc = normalize(adapter: adapter, job: job)

        expect(name).to eq("other.job.enqueue_at")
        expect(title).to eq("Enqueue Skylight::TestJob")
        expect(desc).to eq("{ adapter: 'inline', queue: 'default' }")
      end
    end
  end
end
