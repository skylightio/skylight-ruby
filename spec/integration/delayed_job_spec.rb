require "spec_helper"
require "skylight/instrumenter"
enable = false
begin
  require "delayed_job"
  require "delayed_job_active_record"
  enable = true
rescue LoadError => e
  Kernel.warn "[WARN] Skipping Delayed::Job integration specs; error=#{e}"
end

enable_active_job = false
begin
  require "active_job/base"
  enable_active_job = true
rescue LoadError
  puts "[INFO] Skipping Delayed::Job/ActiveJob integration specs"
end

if enable
  describe "Delayed::Job integration" do
    let(:report_environment) { "production" }
    let(:report_component) { "worker" }
    let(:worker) do
      Delayed::Worker.new.tap do |w|
        w.logger = Logger.new($stdout)
      end
    end

    around do |example|
      with_sqlite(migration: dj_migration) do
        @original_env = ENV.to_hash
        set_agent_env
        Skylight.probe(*probes)
        Skylight.start!(root: __dir__)
        example.call
      ensure
        Skylight.stop!
      end
    end

    before do
      stub_const("SOURCE_LOCATION_KEY", SpecHelper::Messages::Annotation::AnnotationKey.const_get(:SourceLocation))

      # Tests Delayed::Job 'job' class without ActiveJob
      stub_const(
        "SkDelayedWorker",
        Struct.new(:args) do
          def perform
            Skylight.instrument(category: "app.zomg") do
              SpecHelper.clock.skip 1
              raise "bad_method" if args.include?("bad_method")
            end
          end
        end
      )

      # Tests Delayed::Job "PerformableMethod"
      stub_const(
        "SkDelayedObject",
        Class.new do
          def bad_method
            good_method { raise }
          end

          def good_method
            Skylight.instrument(category: "app.zomg") do
              SpecHelper.clock.skip 1
              yield if block_given?
            end
          end

          def self.good_method
            new.good_method
          end
        end
      )
    end

    def probes
      %w[delayed_job]
    end

    after do
      Skylight.stop!
      ENV.replace(@original_env)
    end

    def span_source_location(span, report)
      return unless (sl = span.annotations.detect { |annotation| annotation[:key] == SOURCE_LOCATION_KEY })

      index, line = sl[:val].string_val.split(":").map(&:to_i)
      [report.source_locations[index], line].compact.join(":")
    end

    def file_basename(path)
      Pathname.new(path).basename.to_s
    end

    def format_source_location(unbound_method)
      path, line = unbound_method.source_location
      "#{file_basename(path)}:#{line}"
    end

    def sl_good_method
      format_source_location(SkDelayedObject.instance_method(:good_method))
    end

    def sl_bad_method
      format_source_location(SkDelayedObject.instance_method(:bad_method))
    end

    def next_line(formatted_sl)
      path, line = formatted_sl.split(":")
      [path, line.to_i + 1].join(":")
    end

    def sl_good_method_inner
      next_line(sl_good_method)
    end

    def sl_good_class_method
      format_source_location(SkDelayedObject.method(:good_method))
    end

    def sl_worker_perform
      format_source_location(SkDelayedWorker.instance_method(:perform))
    end

    def sl_worker_perform_inner
      next_line(sl_worker_perform)
    end

    def sl_aj_worker_perform
      format_source_location(SkDelayedActiveJobWorker.instance_method(:perform))
    end

    def sl_aj_worker_perform_inner
      next_line(sl_aj_worker_perform)
    end

    let(:dj_migration) do
      base = ActiveRecord::Migration
      base = defined?(base::Current) ? base::Current : base

      Class.new(base) do
        # Copied from delayed_job_active_record's generator template
        def self.up
          # rubocop:disable Layout/LineLength
          create_table :delayed_jobs, force: true do |table|
            table.integer :priority, default: 0, null: false # Allows some jobs to jump to the front of the queue
            table.integer :attempts, default: 0, null: false # Provides for retries, but still fail eventually.
            table.text :handler,                 null: false # YAML-encoded string of the object that will do work
            table.text :last_error                           # reason for last failure (See Note below)
            table.datetime :run_at                           # When to run. Could be Time.zone.now for immediately, or sometime in the future.
            table.datetime :locked_at                        # Set when a client is working on this object
            table.datetime :failed_at                        # Set when all retries have failed (actually, by default, the record is deleted instead)
            table.string :locked_by                          # Who is working on this object (if locked)
            table.string :queue                              # The name of the queue this job is in
            table.timestamps null: true
          end
          # rubocop:enable Layout/LineLength

          add_index :delayed_jobs, %i[priority run_at], name: "delayed_jobs_priority"
        end

        def self.down
          drop_table :delayed_jobs
        end
      end
    end

    context "with agent", :http, :agent do
      before do
        stub_config_validation
        stub_session_request
      end

      specify do
        enqueue_and_process_job(:good_method)

        server.wait resource: "/report"
        report = server.reports[0].to_simple_report

        expect(report.endpoint.name).to eq("SkDelayedObject#good_method<sk-segment>queue-name</sk-segment>")
        expect(report.mapped_spans).to eq([
          ["app.delayed_job.worker", "Delayed::Worker#run", nil, "delayed_job"],
          ["app.delayed_job.job", "SkDelayedObject#good_method", nil, sl_good_method],
          ["app.zomg", nil, nil, sl_good_method_inner],
          ["db.sql.query", "SQL", "begin transaction", "delayed_job"],
          ["db.sql.query", "DELETE FROM delayed_jobs", "DELETE FROM \"delayed_jobs\" WHERE \"delayed_jobs\".\"id\" = ?", "delayed_job"], # rubocop:disable Layout/LineLength
          ["db.sql.query", "SQL", "commit transaction", "delayed_job"]
        ])
      end

      specify "with a delayed class method" do
        enqueue_and_process_job(:good_method, class_method: true)

        server.wait resource: "/report"
        report = server.reports[0].to_simple_report
        expect(report.endpoint.name).to eq("SkDelayedObject.good_method<sk-segment>queue-name</sk-segment>")
        expect(report.mapped_spans).to eq([
          ["app.delayed_job.worker", "Delayed::Worker#run", nil, "delayed_job"],
          ["app.delayed_job.job", "SkDelayedObject.good_method", nil, sl_good_class_method],
          ["app.zomg", nil, nil, sl_good_method_inner],
          ["db.sql.query", "SQL", "begin transaction", "delayed_job"],
          ["db.sql.query", "DELETE FROM delayed_jobs", "DELETE FROM \"delayed_jobs\" WHERE \"delayed_jobs\".\"id\" = ?", "delayed_job"], # rubocop:disable Layout/LineLength
          ["db.sql.query", "SQL", "commit transaction", "delayed_job"]
        ])
      end

      it "reports problems to the error segment" do
        enqueue_and_process_job(:bad_method)

        server.wait resource: "/report"
        report = server.reports[0].to_simple_report
        expect(report.endpoint.name).to eq("SkDelayedObject#bad_method<sk-segment>error</sk-segment>")
        spans = report.mapped_spans
        expect(spans[0..3]).to eq([
          ["app.delayed_job.worker", "Delayed::Worker#run", nil, "delayed_job"],
          ["app.delayed_job.job", "SkDelayedObject#bad_method", nil, sl_bad_method],
          ["app.zomg", nil, nil, sl_good_method_inner],
          ["db.sql.query", "SQL", "begin transaction", "delayed_job"]
        ])

        expect(spans[4][0]).to eq("db.sql.query")

        # column order can differ between ActiveRecord versions
        r = /UPDATE "delayed_jobs" SET (?<columns>(?:"\w+" = \?,?\s?)+) WHERE "delayed_jobs"\."id" = \?/
        columns = spans[4][2].match(r)[:columns].split(", ")
        expect(columns).to match_array([
          "\"attempts\" = ?",
          "\"last_error\" = ?",
          "\"run_at\" = ?",
          "\"updated_at\" = ?",
          "\"locked_at\" = ?",
          "\"locked_by\" = ?"
        ])
        expect(spans[5]).to eq(["db.sql.query", "SQL", "commit transaction", "delayed_job"])
      end

      context "with a job class" do
        def enqueue_job(*args)
          Delayed::Job.enqueue(SkDelayedWorker.new(args), queue: "my-queue")
        end

        specify do
          enqueue_and_process_job(:good_method)

          server.wait resource: "/report"
          report = server.reports[0].to_simple_report
          expect(report.endpoint.name).to eq("SkDelayedWorker<sk-segment>my-queue</sk-segment>")
          expect(report.mapped_spans).to eq([
            ["app.delayed_job.worker", "Delayed::Worker#run", nil, "delayed_job"],
            ["app.delayed_job.job", "SkDelayedWorker#perform", nil, sl_worker_perform],
            ["app.zomg", nil, nil, sl_worker_perform_inner],
            ["db.sql.query", "SQL", "begin transaction", "delayed_job"],
            ["db.sql.query", "DELETE FROM delayed_jobs", "DELETE FROM \"delayed_jobs\" WHERE \"delayed_jobs\".\"id\" = ?", "delayed_job"], # rubocop:disable Layout/LineLength
            ["db.sql.query", "SQL", "commit transaction", "delayed_job"]
          ])
        end
      end
    end

    def enqueue_job(method_name, *, class_method: false)
      instance_eval("SkDelayedObject#{class_method ? '' : '.new'}.delay(queue: 'queue-name').#{method_name}", __FILE__, __LINE__) # rubocop:disable Layout/LineLength
    end

    def enqueue_and_process_job(*args, class_method: false)
      enqueue_job(*args, class_method: class_method)
      worker.work_off
    end

    enable_active_job && describe("ActiveJob", :http, :agent) do
      # Tests Delayed::Job via ActiveJob

      before do
        stub_const(
          "SkDelayedActiveJobWorker",
          Class.new(ActiveJob::Base) do
            self.queue_adapter = :delayed_job
            self.queue_name = "my-queue"

            def perform(*args)
              Skylight.instrument(category: "app.zomg") do
                SpecHelper.clock.skip 1
                raise "bad_method" if args.include?("bad_method")
              end
            end
          end
        )

        stub_config_validation
        stub_session_request
      end

      def enqueue_job(*args)
        SkDelayedActiveJobWorker.perform_later(*args.map(&:to_s))
      end

      context "both probes installed" do
        def probes
          %w[active_job delayed_job]
        end

        specify do
          enqueue_and_process_job(:good_method)

          server.wait resource: "/report"
          report = server.reports[0].to_simple_report

          expect(report.endpoint.name).to eq("SkDelayedActiveJobWorker<sk-segment>my-queue</sk-segment>")
          expect(report.mapped_spans).to eq([
            ["app.delayed_job.worker", "Delayed::Worker#run", nil, "delayed_job"],
            ["app.delayed_job.job", "ActiveJob::QueueAdapters::DelayedJobAdapter::JobWrapper#perform", nil, "activejob"], # rubocop:disable Layout/LineLength
            ["app.job.perform", "SkDelayedActiveJobWorker", "{ adapter: 'delayed_job', queue: 'my-queue' }", sl_aj_worker_perform], # rubocop:disable Layout/LineLength
            ["app.zomg", nil, nil, sl_aj_worker_perform_inner],
            ["db.sql.query", "SQL", "begin transaction", "delayed_job"],
            ["db.sql.query", "DELETE FROM delayed_jobs", "DELETE FROM \"delayed_jobs\" WHERE \"delayed_jobs\".\"id\" = ?", "delayed_job"], # rubocop:disable Layout/LineLength
            ["db.sql.query", "SQL", "commit transaction", "delayed_job"]
          ])
        end

        it "reports problems to the error segment" do
          enqueue_and_process_job(:bad_method)

          server.wait resource: "/report"
          report = server.reports[0].to_simple_report
          spans = report.mapped_spans

          expect(report.endpoint.name).to eq("SkDelayedActiveJobWorker<sk-segment>error</sk-segment>")
          expect(spans[0..4]).to eq([
            ["app.delayed_job.worker", "Delayed::Worker#run", nil, "delayed_job"],
            ["app.delayed_job.job", "ActiveJob::QueueAdapters::DelayedJobAdapter::JobWrapper#perform", nil, "activejob"], # rubocop:disable Layout/LineLength
            ["app.job.perform", "SkDelayedActiveJobWorker", "{ adapter: 'delayed_job', queue: 'my-queue' }", sl_aj_worker_perform], # rubocop:disable Layout/LineLength
            ["app.zomg", nil, nil, sl_aj_worker_perform_inner],
            ["db.sql.query", "SQL", "begin transaction", "delayed_job"]
          ])

          expect(spans[5][0]).to eq("db.sql.query")

          # column order can differ between ActiveRecord versions
          r = /UPDATE "delayed_jobs" SET (?<columns>(?:"\w+" = \?,?\s?)+) WHERE "delayed_jobs"\."id" = \?/
          columns = spans[5][2].match(r)[:columns].split(", ")
          expect(columns).to match_array([
            "\"attempts\" = ?",
            "\"last_error\" = ?",
            "\"run_at\" = ?",
            "\"updated_at\" = ?",
            "\"locked_at\" = ?",
            "\"locked_by\" = ?"
          ])
          expect(spans[6]).to eq(["db.sql.query", "SQL", "commit transaction", "delayed_job"])
        end
      end
    end
  end
end
