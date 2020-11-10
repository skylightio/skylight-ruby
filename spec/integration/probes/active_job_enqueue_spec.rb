require "spec_helper"

defined?(ActiveJob) && describe("ActiveJob Enqueue integration", :active_job_enqueue_probe, :agent) do
  require "action_mailer"

  before do
    stub_const(
      "TestJob",
      Class.new(ActiveJob::Base) do
        self.queue_adapter = :inline

        def perform; end
      end
    )

    stub_const(
      "TestMailer",
      Class.new(ActionMailer::Base) do
        default from: "test@example.com"

        def test_mail(_arg)
          mail(to: "test@example.com", body: "sk test")
        end
      end
    )

    @job_class =
      if ActionMailer::Base.respond_to?(:delivery_job)
        ActionMailer::Base.delivery_job
      else
        ActionMailer::DeliveryJob
      end

    # NOTE: We don't reset this so it does leak, which could potentially matter in the future
    @job_class.queue_adapter = :inline
  end

  it "reports job metadata" do
    expect_any_instance_of(TestJob).to receive(:perform)
    expect(Skylight).to receive(:instrument).with(
      hash_including(
        title:       "Enqueue TestJob",
        category:    "other.active_job.enqueue",
        description: "{ adapter: 'inline', queue: 'default' }"
      )
    ).and_call_original

    TestJob.perform_later
  end

  it "reports ActionMailer methods" do
    expect_any_instance_of(@job_class).to receive(:perform)
    expect(Skylight).to receive(:instrument).with(
      hash_including(
        title:       "Enqueue TestMailer#test_mail",
        category:    "other.active_job.enqueue",
        description: "{ adapter: 'inline', queue: 'mailers', job: '#{@job_class}' }"
      )
    ).and_call_original

    TestMailer.test_mail(1).deliver_later
  end
end
