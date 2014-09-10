# Util allowing proxying writes to multiple location
# Used from extconf
module Skylight
  module Util
    class MultiIO

      def initialize(*targets)
         @targets = targets
      end

      def write(*args)
        @targets.each {|t| t.write(*args)}
      end

      def close
        @targets.each(&:close)
      end

    end
  end
end
