require "spec_helper"
require "skylight/core/instrumenter"

enable = false
begin
  require "delayed_job"
  require "delayed_job_active_record"
  enable = true
rescue LoadError
  puts "[INFO] Skipping Delayed::Job integration specs"
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
    around do |example|
      with_sqlite(&example)
    end

    let(:probes) { %w[delayed_job] }

    before do
      @original_env = ENV.to_hash
      set_agent_env
      migration = dj_migration # Schema.define instance_evals the block, so this must be a local var
      ActiveRecord::Schema.define { migration.up }
      Skylight.probe(*probes)
      Skylight.start!
    end

    after { Skylight.stop! }

    class DelayedObject
      def bad_method
        good_method { raise }
      end

      def good_method
        Skylight.instrument(category: "app.zomg") do
          sleep(0.1)
          yield if block_given?
        end
      end
    end

    let(:dj_migration) do
      base = ActiveRecord::Migration
      base = defined?(base::Current) ? base::Current : base

      Class.new(base) do
        # Copied from delayed_job_active_record's generator template
        def self.up
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
        run_job(:good_method)

        server.wait resource: "/report"
        endpoint = server.reports[0].endpoints[0]
        trace = endpoint.traces[0]
        spans = trace.filtered_spans

        expect(endpoint.name).to eq("DelayedObject#good_method<sk-segment>queue-name</sk-segment>")
        expect(spans.map { |s| [s.event.category, s.event.description] }).to eq([
          ["app.delayed_job.worker", nil],
          ["app.zomg", nil],
          ["db.sql.query", "begin transaction"],
          ["db.sql.query", "DELETE FROM \"delayed_jobs\" WHERE \"delayed_jobs\".\"id\" = ?"],
          ["db.sql.query", "commit transaction"]
        ])
      end

      it "reports problems to the error segment" do
        run_job(:bad_method)

        server.wait resource: "/report"
        endpoint = server.reports[0].endpoints[0]
        trace = endpoint.traces[0]
        spans = trace.filtered_spans

        expect(endpoint.name).to eq("DelayedObject#bad_method<sk-segment>error</sk-segment>")
        meta = spans.map { |s| [s.event.category, s.event.description] }
        expect(meta[0]).to eq(["app.delayed_job.worker", nil])
        expect(meta[1]).to eq(["app.zomg", nil])
        expect(meta[2]).to eq(["db.sql.query", "begin transaction"])

        expect(meta[3][0]).to eq("db.sql.query")

        # column order can differ between ActiveRecord versions
        r = /UPDATE "delayed_jobs" SET (?<columns>((\"\w+\") = \?,?\s?)+) WHERE "delayed_jobs"\."id" = \?/
        columns = meta[3][1].match(r)[:columns].split(", ")
        expect(columns).to match_array([
          "\"attempts\" = ?",
          "\"last_error\" = ?",
          "\"run_at\" = ?",
          "\"updated_at\" = ?"
        ])
        expect(meta[4]).to eq(["db.sql.query", "commit transaction"])
      end
    end

    def run_job(method_name, *)
      job = instance_eval("DelayedObject.new.delay(queue: 'queue-name').#{method_name}", __FILE__, __LINE__)
      Delayed::Worker.new.run(job)
    end

    enable_active_job && describe("active_job integration") do
      let(:probes) { %w[active_job delayed_job] }

      class DelayedWorker < ActiveJob::Base
        self.queue_adapter = :delayed_job
        self.queue_name = 'my-queue'

        def perform(*args)
          Skylight.instrument(category: "app.zomg") do
            sleep(0.1)
            raise "bad_method" if args.include?("bad_method")
            p args
          end
        end
      end

      def run_job(*args)
        DelayedWorker.queue_adapter = :delayed_job # Rails 4 :(
        DelayedWorker.perform_later(*args.map(&:to_s))
        job = Delayed::Job.last
        Delayed::Worker.new.run(job)
      end

      context "with agent", :http, :agent do
        before do
          stub_config_validation
          stub_session_request
        end

        specify do
          run_job(:good_method)

          server.wait resource: "/report"
          endpoint = server.reports[0].endpoints[0]
          trace = endpoint.traces[0]
          spans = trace.filtered_spans

          expect(endpoint.name).to eq("DelayedWorker<sk-segment>my-queue</sk-segment>")
          expect(spans.map { |s| [s.event.category, s.event.description] }).to eq([
            ["app.delayed_job.worker", nil],
            ["app.job.perform", "{ adapter: 'delayed_job', queue: 'my-queue' }"],
            ["app.zomg", nil],
            ["db.sql.query", "begin transaction"],
            ["db.sql.query", "DELETE FROM \"delayed_jobs\" WHERE \"delayed_jobs\".\"id\" = ?"],
            ["db.sql.query", "commit transaction"]
          ])
        end

        it "reports problems to the error segment" do
          run_job(:bad_method)

          server.wait resource: "/report"
          endpoint = server.reports[0].endpoints[0]
          trace = endpoint.traces[0]
          spans = trace.filtered_spans

          expect(endpoint.name).to eq("DelayedWorker<sk-segment>error</sk-segment>")
          meta = spans.map { |s| [s.event.category, s.event.description] }
          expect(meta[0]).to eq(["app.delayed_job.worker", nil])
          expect(meta[1]).to eq(["app.job.perform", "{ adapter: 'delayed_job', queue: 'my-queue' }"])
          expect(meta[2]).to eq(["app.zomg", nil])
          expect(meta[3]).to eq(["db.sql.query", "begin transaction"])

          expect(meta[4][0]).to eq("db.sql.query")

          # column order can differ between ActiveRecord versions
          r = /UPDATE "delayed_jobs" SET (?<columns>((\"\w+\") = \?,?\s?)+) WHERE "delayed_jobs"\."id" = \?/
          columns = meta[4][1].match(r)[:columns].split(", ")
          expect(columns).to match_array([
            "\"attempts\" = ?",
            "\"last_error\" = ?",
            "\"run_at\" = ?",
            "\"updated_at\" = ?"
          ])
          expect(meta[5]).to eq(["db.sql.query", "commit transaction"])
        end
      end
    end
  end
end
