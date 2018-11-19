module Skylight
  module Core
    module Fanout
      def self.registered
        @registered ||= []
      end

      def self.register(obj)
        registered.push(obj)
      end

      def self.unregister(obj)
        registered.delete(obj)
      end

      def self.trace(*args)
        registered.map { |r| r.trace(*args) }
      end

      def self.instrument(*args)
        if block_given?
          spans = instrument(*args)
          meta = {}
          begin
            yield spans
          ensure
            done(spans, meta)
          end
        else
          registered.map do |r|
            [r, r.instrument(*args)]
          end
        end
      end

      def self.done(spans, meta = nil)
        spans.reverse_each do |(target, span)|
          target.done(span, meta)
        end
      end

      def self.broken!
        registered.each(&:broken!)
      end

      def self.endpoint=(endpoint)
        each_trace { |t| t.endpoint = endpoint }
      end

      def self.each_trace
        return to_enum(__method__) unless block_given?
        registered.each do |r|
          next unless r.instrumenter && (trace = r.instrumenter.current_trace)
          yield trace
        end
      end
    end
  end
end
