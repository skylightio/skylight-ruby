module Skylight
  module Worker
    class Collector < Util::Task
      ENDPOINT     = '/report'.freeze
      FLUSH_DELAY  = 0.5
      CONTENT_TYPE = 'content-type'.freeze
      SKYLIGHT_V1  = 'application/x-skylight-report-v1'.freeze

      include Util::Logging

      attr_reader :config

      def initialize(config)
        super(1000)

        @config   = config
        @http     = Util::HTTP.new(config)
        @size     = config[:'agent.sample']
        @batch    = nil
        @interval = config[:'agent.interval']
      end

      def handle(msg, now = Util::Clock.now)
        @batch ||= new_batch(now)

        if @batch.should_flush?(now)
          flush(@batch)
          @batch = new_batch(now)
        end

        return true unless msg

        if Messages::Trace === msg
          @batch.push(msg)
        else
          debug "Received unknown message; class=%s", msg.class.to_s
        end

        true
      end

    private

      def finish
        flush(@batch) if @batch
        @batch = nil
      end

      def flush(batch)
        return if batch.empty?

        trace "flushing batch; size=%d", batch.sample.count
        @http.post(ENDPOINT, batch.encode, CONTENT_TYPE => SKYLIGHT_V1)
      end

      def new_batch(now)
        Batch.new(@size, round(now), @interval)
      end

      def round(time)
        (time.to_i / @interval) * @interval
      end

      class Batch
        attr_reader :from, :counts, :sample

        def initialize(size, from, interval)
          @from     = from
          @flush_at = from + interval + FLUSH_DELAY
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

        def encode
          endpoints = {}

          sample.each do |trace|
            next unless name = trace.endpoint
            trace.endpoint = nil

            ep = (endpoints[name] ||= Messages::Endpoint.new(
              name: name, traces: [], count: @counts[name]))

            ep.traces << trace
          end

          Messages::Batch.new(
            timestamp: from,
            endpoints: endpoints.values).
            encode.to_s
        end
      end

    end
  end
end
