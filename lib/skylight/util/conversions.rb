module Skylight
  module Util
    module Conversions
      def secs_to_nanos(secs)
        secs * 1_000_000_000
      end
    end
  end
end
