module Skylight
  module Worker
    class Collector < Util::Task

      def initialize
        super(1000)
      end

      def handle(msg)
        if msg
          p [ :COLLECTOR, msg ]
        end
        true
      end

    end
  end
end
