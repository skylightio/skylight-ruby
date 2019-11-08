require "logger"

module Skylight
  module Util
    # Log both to the specified logger and STDOUT
    class AlertLogger
      def initialize(logger)
        @logger = logger
      end

      def write(*args)
        STDERR.write(*args)

        # Try to avoid writing to STDOUT/STDERR twice
        logger_logdev = @logger.instance_variable_get(:@logdev)
        logger_out = logger_logdev&.respond_to?(:dev) ? logger_logdev.dev : nil
        if logger_out != STDOUT && logger_out != STDERR
          @logger.<<(*args)
        end
      end

      def close; end
    end

    module Logging
      def log_context
        {}
      end

      def trace?
        !!ENV[-"SKYLIGHT_ENABLE_TRACE_LOGS"]
      end

      def raise_on_error?
        !!ENV[-"SKYLIGHT_RAISE_ON_ERROR"]
      end

      # Logs if tracing
      #
      # @param (see #debug)
      #
      # See {trace?}.
      def trace(msg, *args)
        return unless trace?

        log :debug, msg, *args
      end

      # Evaluates and logs the result of the block if tracing
      #
      # @yield block to be evaluted
      # @yieldreturn arguments for {#debug}
      #
      # See {trace?}.
      def t
        return unless trace?

        log :debug, yield
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
        raise format(msg, *args) if raise_on_error?
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

      def config_for_logging
        if respond_to?(:config)
          config
        elsif is_a?(Skylight::Config)
          self
        end
      end

      # @param level [String,Symbol] the method on `logger` to use for logging
      # @param msg [String] the message to log
      # @param args [Array] values for `Kernel#sprintf` on `msg`
      def log(level, msg, *args)
        c = config_for_logging
        logger = c ? c.logger : nil

        msg = log_context.map { |(k, v)| "#{k}=#{v}; " }.join << msg

        if logger
          if logger.respond_to?(level)
            if !args.empty?
              logger.send level, format(msg, *args)
            else
              logger.send level, msg
            end
            return
          else
            Kernel.warn "Invalid logger"
          end
        end

        # Fallback
        if (module_name = is_a?(Module) ? name : self.class.name)
          root_name = module_name.split("::").first.upcase
          msg.prepend("[#{root_name}] ")
        end
        puts format(msg, *args)
      rescue Exception => e
        if trace?
          puts "[ERROR] #{e.message}"
          puts e.backtrace
        end
      end
    end
  end
end
