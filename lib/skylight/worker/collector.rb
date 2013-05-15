module Skylight
  module Worker
    class Collector < Util::Task

      def initialize
        super(1000)
      end

      def tick(msg)
        p [ :COLLECTOR, msg ]
        true
      end

    end
  end
end
