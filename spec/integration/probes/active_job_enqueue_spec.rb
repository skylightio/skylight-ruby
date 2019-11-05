require "spec_helper"

defined?(ActiveJob) && describe("ActiveJob Enqueue integration", :active_job_enqueue_probe, :agent) do
  require "action_mailer"

  class TestJob < ActiveJob::Base
    self.queue_adapter = :inline

    def perform; end
  end

  ActionMailer::DeliveryJob.queue_adapter = :inline

  class TestMailer < ActionMailer::Base
    default from: "test@example.com"

    def test_mail(_arg)
      mail(to: "test@example.com", body: "sk test")
    end
  end

  it "reports job metadata" do
    expect_any_instance_of(TestJob).to receive(:perform)
    expect(Skylight).to receive(:instrument).with(
      hash_including(
        title: "Enqueue TestJob",
        category: "other.active_job.enqueue",
        description: "{ adapter: 'inline', queue: 'default' }"
      )
    ).and_call_original

    TestJob.perform_later
  end

  it "reports ActionMailer methods" do
    expect_any_instance_of(ActionMailer::DeliveryJob).to receive(:perform)
    expect(Skylight).to receive(:instrument).with(
      hash_including(
        title: "Enqueue TestMailer#test_mail",
        category: "other.active_job.enqueue",
        description: "{ adapter: 'inline', queue: 'mailers', job: 'ActionMailer::DeliveryJob' }"
      )
    ).and_call_original

    TestMailer.test_mail(1).deliver_later
  end
end
