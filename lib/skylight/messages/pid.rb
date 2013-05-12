module Skylight
  module Messages
    class Pid
      def read
        raise NotImplementedError
      end

      attr_reader :pid

      def initialize(pid)
        @pid = pid
      end

      def to_bytes
        [ pid ].pack('L')
      end
    end
  end
end
