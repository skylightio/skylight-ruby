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
        # The second set is picked up by YARD
        def trace(msg, *args)
          log :debug, msg, *args
        end

        def t
          log :debug, yield
        end
      else
        # Logs if `ENV[TRACE_ENV_KEY]` is set.
        #
        # @param (see #debug)
        #
        # See {TRACE_ENV_KEY}.
        def trace(msg, *args)
        end

        # Evaluates and logs the result of the block if `ENV[TRACE_ENV_KEY]` is set
        #
        # @yield block to be evaluted
        # @yieldreturn arguments for {#debug}
        #
        # See {TRACE_ENV_KEY}.
        def t
        end
      end

      # @param msg (see #log)
      # @param args (see #log)
      def debug(msg, *args)
        log :debug, msg, *args
      end

      # @param msg (see #log)
      # @param args (see #log)
      def info(msg, *args)
        log :info, msg, *args
      end

      # @param msg (see #log)
      # @param args (see #log)
      def warn(msg, *args)
        log :warn, msg, *args
      end

      # @param msg (see #log)
      # @param args (see #log)
      def error(msg, *args)
        log :error, msg, *args
        raise sprintf(msg, *args) if ENV['SKYLIGHT_RAISE_ON_ERROR']
      end

      alias log_trace trace
      alias log_debug debug
      alias log_info  info
      alias log_warn  warn
      alias log_error error

      # Alias for `Kernel#sprintf`
      # @return [String]
      def fmt(*args)
        sprintf(*args)
      end

      # @param level [String,Symbol] the method on `logger` to use for logging
      # @param msg [String] the message to log
      # @param args [Array] values for `Kernel#sprintf` on `msg`
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
