require "spec_helper"

enable = false
begin
  require "skylight/probes/active_job"
  require "active_job/base"
  require "active_job/test_helper"
  require "skylight/railtie"
  enable = true
rescue LoadError
  puts "[INFO] Skipping active_job integration specs"
end

if enable
  class SkTestJob < ActiveJob::Base
    # rubocop:disable Lint/InheritException
    class Exception < ::Exception
    end
    # rubocop:enable Lint/InheritException

    def perform(error_key = nil)
      Skylight.instrument category: "app.inside" do
        Skylight.instrument category: "app.zomg" do
          # no-op
          SpecHelper.clock.skip 1

          maybe_raise(error_key)
        end

        Skylight.instrument(category: "app.after_zomg") { SpecHelper.clock.skip 1 }
      end
    end

    private

      def maybe_raise(key)
        return unless key

        err = {
          "runtime_error" => RuntimeError,
          "exception"     => Exception
        }[key]

        raise err if err
      end
  end

  describe "ActiveJob integration", :http, :agent do
    let(:report_component) { "worker" }
    let(:report_environment) { "production" }

    around do |ex|
      stub_config_validation
      stub_session_request

      # Prior to rails 5, queue_adapter was a class variable,
      # so setting it to delayed_job in the DelayedJob spec could cause
      # these tests to fail
      # NOTE: We don't reset this so it does leak, which could potentially matter in the future
      ActiveJob::Base.queue_adapter = :inline if ActiveJob::VERSION::MAJOR < 5

      set_agent_env do
        Skylight.start!
        ex.call
        Skylight.stop!
      end
    end

    include ActiveJob::TestHelper

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
      expect(endpoint.name).to eq("SkTestJob<sk-segment>default</sk-segment>")
    end

    context "action mailer jobs" do
      require "action_mailer"

      class TestMailer < ActionMailer::Base
        default from: "test@example.com"

        def test_mail(_arg)
          mail(to: "test@example.com", subject: "ActiveJob test", body: SecureRandom.hex)
        end
      end

      specify do
        allow_any_instance_of(ActionMailer::MessageDelivery).to receive(:deliver_now)

        TestMailer.test_mail(1).deliver_later

        server.wait(count: 1)

        expected_endpoint = "TestMailer#test_mail<sk-segment>mailers</sk-segment>"
        expect(server.reports[0].endpoints[0].name).to eq(expected_endpoint)
      end
    end

    context "error handling" do
      it "assigns failed jobs to the error queue" do
        begin
          SkTestJob.perform_later("runtime_error")
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
        expect(endpoint.name).to eq("SkTestJob<sk-segment>error</sk-segment>")
      end

      it "assigns jobs that raise exceptions to the error queue" do
        begin
          SkTestJob.perform_later("exception")
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
        expect(endpoint.name).to eq("SkTestJob<sk-segment>error</sk-segment>")
      end
    end
  end
end
