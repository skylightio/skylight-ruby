require 'logger'

module Skylight
  module Util
    # Log both to the specified logger and STDOUT
    class AlertLogger
      def initialize(logger)
        @logger = logger
      end

      def write(*args)
        STDERR.write *args

        # Try to avoid writing to STDOUT/STDERR twice
        logger_logdev = @logger.instance_variable_get(:@logdev)
        logger_out = logger_logdev && logger_logdev.respond_to?(:dev) ? logger_logdev.dev : nil
        if logger_out != STDOUT && logger_out != STDERR
          @logger.<<(*args)
        end
      end

      def close
      end
    end

    module Logging
      def self.trace?
        ENV[TRACE_ENV_KEY]
      end

      if trace?
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
        raise sprintf(msg, *args) if ENV['SKYLIGHT_RAISE_ON_ERROR']
        log :error, msg, *args
      end

      alias log_trace trace
      alias log_debug debug
      alias log_info  info
      alias log_warn  warn
      alias log_error error

      alias fmt       sprintf

      def log(level, msg, *args)
        c = if respond_to?(:config)
          config
        elsif self.is_a?(Config)
          self
        end

        return unless c

        if logger = c.logger
          return unless logger.respond_to?(level)

          if args.length > 0
            logger.send level, sprintf("[SKYLIGHT] [#{Skylight::VERSION}] #{msg}", *args)
          else
            logger.send level, "[SKYLIGHT] [#{Skylight::VERSION}] #{msg}"
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
