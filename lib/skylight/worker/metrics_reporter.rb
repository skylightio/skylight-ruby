require 'thread'
require 'rbconfig'

module Skylight
  module Worker
    class MetricsReporter < Util::Task

      include Util::Logging

      attr_reader :config

      def initialize(config)
        super(1000, 0.25)

        @metrics = {}
        @config = config
        @interval = config[:'metrics.report_interval']
        @lock = Mutex.new
        @next_report_at = nil
        @http_auth = Util::HTTP.new(config, :accounts)
      end

      # A metric responds to #call and returns metric info
      def register(name, metric)
        @lock.synchronize { @metrics[name] = metric }
      end

      def unregister(name)
        @lock.synchronize { @metrics.delete(name) }
      end

      # msg is always nil, but we can use the Task abstraction anyway
      def handle(msg, now = Util::Clock.absolute_secs)
        # Initially set the next report at
        unless @next_report_at
          update_next_report_at(now)
          return true
        end

        if now < @next_report_at
          # Nothing to do
          return true
        end

        update_next_report_at(now)
        post_report

        true
      end

      def build_report
        report = {
          "hostname"           => config[:'hostname'],
          "host.info"          => RbConfig::CONFIG['arch'],
          "ruby.version"       => "#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL}",
          "ruby.engine"        => RUBY_ENGINE,
          "skylight.version"   => Skylight::VERSION
        }

        metric_names.each do |name|
          # Since we are operating in a concurrent environment, it is possible
          # that the metric for the current name is unregistered before we
          # access it here.
          unless m = metric(name)
            next
          end

          report[name] = m.call
        end

        report
      end

      def post_report
        report = build_report

        # Send the report
        t { fmt "reporting internal metrics; payload=%s", report.inspect }

        res = @http_auth.post("/agent/metrics", report: report)

        unless res.success?
          warn "internal metrics report failed; status=%s", res.status
        end
      end

    private

      def metric_names
        @lock.synchronize { @metrics.keys }
      end

      def metric(name)
        @lock.synchronize { @metrics[name] }
      end

      def update_next_report_at(now)
        @next_report_at = now + @interval
      end

    end
  end
end
