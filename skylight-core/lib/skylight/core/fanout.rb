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
        registered.map{|r| r.trace(*args) }
      end

      def self.instrument(*args)
        if block_given?
          spans = instrument(*args)
          begin
            yield
          ensure
            done(spans)
          end
        else
          registered.map do |r|
            [r, r.instrument(*args)]
          end
        end
      end

      def self.done(spans)
        spans.reverse.each do |(target, span)|
          target.done(span)
        end
      end

    end
  end
end
