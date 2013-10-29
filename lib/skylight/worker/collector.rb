require 'uri'

module Skylight
  module Worker
    class Collector < Util::Task
      include URI::Escape

      ENDPOINT     = '/report'.freeze
      CONTENT_TYPE = 'content-type'.freeze
      SKYLIGHT_V1  = 'application/x-skylight-report-v1'.freeze

      include Util::Logging

      attr_reader :config

      def initialize(config)
        super(1000, 0.25)

        @config      = config
        @size        = config[:'agent.sample']
        @batch       = nil
        @interval    = config[:'agent.interval']
        @buf         = ""
        @refresh_at  = 0
        @http_auth   = Util::HTTP.new(config, :accounts)
        @http_report = nil
        # @http_report = Util::HTTP.new(config, :report)

        t { fmt "starting collector; interval=%d; size=%d", @interval, @size }
      end

      def handle(msg, now = Util::Clock.secs)
        @batch ||= new_batch(now)

        if should_refresh_token?(now)
          refresh_report_token(now)
        end

        if @batch.should_flush?(now)
          if has_report_token?(now)
            flush(@batch)
          else
            warn "do not have valid session token -- dropping"
            return
          end

          @batch = new_batch(now)
        end

        return true unless msg

        case msg
        when Messages::Trace
          t { fmt "collector received trace" }
          @batch.push(msg)
        when Messages::Error
          send_error(msg)
        else
          debug "Received unknown message; class=%s", msg.class.to_s
        end

        true
      end

    private

      def send_error(msg)
        res = @http_auth.post("/agent/error?hostname=#{escape(config[:'hostname'])}")

        unless res.success?
          if (400..499).include? @res.status
            warn "error wasn't sent successfully; status=%s", res.status
          end

          warn "could not fetch report session token; status=%s", res.status
          return
        end
      rescue Exception => e
        error "exception; msg=%s; class=%s", e.message, e.class
        t { e.backtrace.join("\n") }
      end

      def finish
        t { fmt "collector finishing up" }

        now = Util::Clock.secs

        if should_refresh_token?(now)
          refresh_report_token(now)
        end

        if @batch && has_report_token?(now)
          flush(@batch)
        end

        @batch = nil
      end

      def flush(batch)
        return if batch.empty?

        debug "flushing batch; size=%d", batch.sample.count

        @buf.clear
        @http_report.post(ENDPOINT, batch.encode(@buf), CONTENT_TYPE => SKYLIGHT_V1)
      end

      def refresh_report_token(now)
        res = @http_auth.get("/agent/authenticate?hostname=#{escape(config[:'hostname'])}")

        unless res.success?
          if (400..499).include? @res.status
            warn "token request rejected; status=%s", res.status
            @http_report = nil
          end

          warn "could not fetch report session token; status=%s", res.status
          return
        end

        tok = res.body['session']
        tok = tok['token'] if tok

        if tok
          @refresh_at  = now + 30
          @http_report = Util::HTTP.new(config, :report)
          @http_report.authentication = tok
        else
          if @http_report
            @refresh_at = now + 30
          end
          warn "server did not return a session token"
        end
      rescue Exception => e
        error "exception; msg=%s; class=%s", e.message, e.class
        t { e.backtrace.join("\n") }
      end

      def should_refresh_token?(now)
        now >= @refresh_at
      end

      def has_report_token?(now)
        return unless @http_report
        now < @refresh_at + (3600 * 3 - 660)
      end

      def new_batch(now)
        Batch.new(config, @size, round(now), @interval)
      end

      def round(time)
        (time.to_i / @interval) * @interval
      end

      class Batch
        include Util::Logging

        attr_reader :config, :from, :counts, :sample, :flush_at

        def initialize(config, size, from, interval)
          @config   = config
          @from     = from
          @flush_at = from + interval
          @sample   = Util::UniformSample.new(size)
          @counts   = Hash.new(0)
        end

        def should_flush?(now)
          now >= @flush_at
        end

        def empty?
          @sample.empty?
        end

        def push(trace)
          # Count it
          @counts[trace.endpoint] += 1
          # Push the trace into the sample
          @sample << trace
        end

        def encode(buf)
          endpoints = {}

          sample.each do |trace|
            unless name = trace.endpoint
              debug "trace missing name -- dropping"
              next
            end

            trace.endpoint = nil

            ep = (endpoints[name] ||= Messages::Endpoint.new(
              name: name, traces: [], count: @counts[name]))

            ep.traces << trace
          end

          t { fmt "encoding batch; endpoints=%p", endpoints.keys }

          Messages::Batch.new(
            timestamp: from,
            hostname:  config[:hostname],
            endpoints: endpoints.values).
            encode(buf)

          buf
        end
      end

    end
  end
end
