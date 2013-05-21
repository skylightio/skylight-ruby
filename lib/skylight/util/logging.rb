module Skylight
  module Util
    module Logging
      def trace(msg, *args)
        printf("[TRACE] #{msg}\n", *args)
      rescue
      end

      def debug(msg, *args)
        printf("[DEBUG] #{msg}\n", *args)
      rescue
      end

      def info(msg, *args)
        printf(" [INFO] #{msg}\n", *args)
      rescue
      end

      def warn(msg, *args)
        printf(" [WARN] #{msg}\n", *args)
      rescue
      end

      def error(msg, *args)
        printf("[ERROR] #{msg}\n", *args)
      rescue
      end
    end
  end
end
