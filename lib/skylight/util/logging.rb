require 'logger'

module Skylight
  module Util
    module Logging
      if ENV[TRACE_ENV_KEY]
        def trace(msg, *args)
          log :DEBUG, msg, *args
        end

        def t
          log :DEBUG, yield
        end
      else
        def trace(*)
        end

        def t
        end
      end

      def debug(msg, *args)
        log :DEBUG, msg, *args
      end

      def info(msg, *args)
        log :INFO, msg, *args
      end

      def warn(msg, *args)
        log :WARN, msg, *args
      end

      def error(msg, *args)
        log :ERROR, msg, *args
      end

      alias fmt sprintf

      MAP = {
        :DEBUG => Logger::DEBUG,
        :INFO  => Logger::INFO,
        :WARN  => Logger::WARN,
        :ERROR => Logger::ERROR }

      def log(level, msg, *args)
        return unless respond_to?(:config)
        return unless c = config

        if logger = c.logger
          if args.length > 0
            logger.log MAP[level], sprintf("[SKYLIGHT] #{msg}", *args)
          else
            logger.log MAP[level], "[SKYLIGHT] #{msg}"
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
