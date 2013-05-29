require 'logger'

module Skylight
  module Util
    module Logging
      if ENV[TRACE_ENV_KEY]
        def trace(msg, *args)
          log :debug, msg, *args
        end

        def t
          log :debug, yield
        end
      else
        def trace(*)
        end

        def t
        end
      end

      def debug(msg, *args)
        log :debug, msg, *args
      end

      def info(msg, *args)
        log :info, msg, *args
      end

      def warn(msg, *args)
        log :warn, msg, *args
      end

      def error(msg, *args)
        log :error, msg, *args
      end

      alias fmt sprintf

      def log(level, msg, *args)
        return unless respond_to?(:config)
        return unless c = config

        if logger = c.logger
          return unless logger.respond_to?(level)

          if args.length > 0
            logger.send level, sprintf("[SKYLIGHT] #{msg}", *args)
          else
            logger.send level, "[SKYLIGHT] #{msg}"
          end
        end
      rescue Exception => e
        if ENV[TRACE_ENV_KEY]
          puts "[ERROR] #{e.message}"
          puts e.backtrace
        end
      end

    end
  end
end
