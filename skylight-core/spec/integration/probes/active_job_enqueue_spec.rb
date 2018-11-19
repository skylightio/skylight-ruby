require "spec_helper"

defined?(ActiveJob) && describe("ActiveJob Enqueue integration", :active_job_enqueue_probe, :agent) do
  class TestJob < ActiveJob::Base
    self.queue_adapter = :inline

    def perform; end
  end

  it "reports job metadata" do
    expect_any_instance_of(TestJob).to receive(:perform)
    expect(TestNamespace).to receive(:instrument).with(
      hash_including(
        title: "Enqueue TestJob",
        category: "other.active_job.enqueue",
        description: "{ adapter: inline, queue: 'default' }"
      )
    )

    TestJob.perform_later
  end
end
