require 'uri'

module Skylight
  module Worker
    class Collector < Util::Task
      include URI::Escape

      ENDPOINT     = '/report'.freeze
      CONTENT_TYPE = 'content-type'.freeze
      SKYLIGHT_V2  = 'application/x-skylight-report-v2'.freeze

      include Util::Logging

      attr_reader :config

      def initialize(config)
        super(1000, 0.25)

        @config      = config
        @size        = config[:'agent.sample']
        @batch       = nil
        @interval    = config[:'agent.interval']
        @refresh_at  = 0
        @http_auth   = Util::HTTP.new(config, :accounts)
        @http_report = nil
        # @http_report = Util::HTTP.new(config, :report)

        t { fmt "starting collector; interval=%d; size=%d", @interval, @size }
      end

      def handle(msg, now = Util::Clock.absolute_secs)
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
        when Messages::TraceEnvelope
          t { fmt "collector received trace" }
          @batch.push(msg)
        when Error
          send_error(msg)
        else
          debug "Received unknown message; class=%s", msg.class.to_s
        end

        true
      end

      def send_status(status)
        post_data(:status, status)
      end

      def send_exception(exception)
        data = {class_name: exception.class.name}
        if Exception === exception
          data.merge!(message: exception.message, backtrace: exception.backtrace)
        end
        post_data(:exception, data, false)
      end

    private

      def post_data(type, data, notify = true)
        t { "posting data (#{type}): #{data.inspect}" }

        res = @http_auth.post("/agent/#{type}?hostname=#{escape(config[:'hostname'])}", data)

        unless res.success?
          warn "#{type} wasn't sent successfully; status=%s", res.status
        end

        send_exception(res.exception) if notify && res.exception
      rescue Exception => e
        error "exception; msg=%s; class=%s", e.message, e.class
        t { e.backtrace.join("\n") }
      end

      def send_error(msg)
        details = msg.details ? JSON.parse(msg.details) : nil
        post_data(:error, type: msg.type, description: msg.description, details: details)
      end

      def finish
        t { fmt "collector finishing up" }

        now = Util::Clock.absolute_secs

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

        res = @http_report.post(ENDPOINT, batch.encode, CONTENT_TYPE => SKYLIGHT_V2)
        send_exception(res.exception) if res.exception
        nil
      end

      def refresh_report_token(now)
        res = @http_auth.get("/agent/authenticate?hostname=#{escape(config[:'hostname'])}")

        if res.exception
          send_exception(res.exception)
          return
        end

        unless res.success?
          if (400..499).include? res.status
            warn "token request rejected; status=%s", res.status
            @http_report = nil
          end

          warn "could not fetch report session token; status=%s", res.status
          return
        end

        tok = res.body['session']
        tok = tok['token'] if tok

        if tok
          @refresh_at  = now + 1800 # 30 minutes
          @http_report = Util::HTTP.new(config, :report)
          @http_report.authentication = tok
        else
          if @http_report
            @refresh_at = now + 60
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
        return true if config.ignore_token?
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
          return true if @config.constant_flush?
          now >= @flush_at
        end

        def empty?
          @sample.empty?
        end

        def push(trace)
          # Count it
          @counts[trace.endpoint_name] += 1
          # Push the trace into the sample
          @sample << trace
        end

        def encode
          batch = Skylight::Batch.native_new(from, config[:hostname])

          sample.each do |trace|
            batch.native_move_in(trace.data)
          end

          @counts.each do |endpoint_name,count|
            batch.native_set_endpoint_count(endpoint_name, count)
          end

          batch.native_serialize
        end
      end

    end
  end
end
