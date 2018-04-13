require "spec_helper"

enable = false
begin
  require "active_job"
  enable = true
rescue LoadError
  puts "[INFO] Skipping Active Job unit tests"
end

if enable
  module Skylight::Core
    describe "ActiveJob", "enqueue_at.active_job", :agent do
      before do
        Normalizers.enable("active_job")
      end

      after do
        Normalizers.disable("active_job")
      end

      class TestJob < ::ActiveJob::Base
      end

      it "normalizes the notification name with defaults" do
        adapter = ActiveJob::QueueAdapters::InlineAdapter.new
        job = TestJob.new

        name, title, desc = normalize(adapter: adapter, job: job)

        expect(name).to eq("other.job.enqueue_at")
        expect(title).to eq("Enqueue Skylight::Core::TestJob")
        expect(desc).to eq("{ adapter: 'inline', queue: 'default' }")
      end
    end
  end
end
