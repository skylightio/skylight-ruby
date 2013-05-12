module Skylight
  module Util
    module Logging
      def trace(msg, *args)
        printf("[TRACE] #{msg}\n", *args)
      end

      def debug(msg, *args)
        printf("[DEBUG] #{msg}\n", *args)
      end

      def info(msg, *args)
        printf("[INFO]  #{msg}\n", *args)
      end

      def warn(msg, *args)
        printf("[WARN]  #{msg}\n", *args)
      end

      def error(msg, *args)
        printf("[ERROR] #{msg}\n", *args)
      end
    end
  end
end
