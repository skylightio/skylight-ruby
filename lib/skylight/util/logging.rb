require 'logger'

module Skylight
  module Util
    module Logging
      if ENV[TRACE_ENV_KEY]
        def trace(msg, *args)
          log :DEBUG, msg, *args
        end
      else
        def trace(*)
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

      MAP = {
        :DEBUG => Logger::DEBUG,
        :INFO  => Logger::INFO,
        :WARN  => Logger::WARN,
        :ERROR => Logger::ERROR }

      def log(level, msg, *args)
        return unless respond_to?(:config)
        return unless c = config

        if logger = c.logger
          logger.log MAP[level], sprintf("[SKYLIGHT] #{msg}\n", *args)
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
