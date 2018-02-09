module Skylight
  module Core
    module Instrumentable

      def self.included(base)
        base.extend(Util::Logging)
        base.extend(ClassMethods)

        base.const_set(:LOCK, Mutex.new)

        base.class_eval do
          at_exit do
            if RUBY_VERSION == '1.9.2'
              # workaround for MRI bug losing exit status in at_exit block
              # http://bugs.ruby-lang.org/issues/5218
              exit_status = $!.status if $!.is_a?(SystemExit)
              stop!
              exit exit_status if exit_status
            else
              stop!
            end
          end
        end

        Skylight::Core::Fanout.register(base)
      end

      module ClassMethods

        def instrumenter_class
          Skylight::Core::Instrumenter
        end

        def instrumenter
          @instrumenter
        end

        def correlation_header
          nil
        end

        # Start instrumenting
        def start!(config=nil)
          return @instrumenter if @instrumenter

          const_get(:LOCK).synchronize do
            return @instrumenter if @instrumenter

            config ||= {}
            config = config_class.load(config) unless config.is_a?(config_class)

            @instrumenter = instrumenter_class.new(config).start!
          end
        rescue => e
          message = sprintf("Unable to start Instrumenter; msg=%s; class=%s", e.message, e.class)
          if config && config.respond_to?(:logger)
            config.logger.warn message
          else
            warn "[#{name.upcase}] #{message}"
          end
          false
        end

        # Stop instrumenting
        def stop!
          const_get(:LOCK).synchronize do
            return unless @instrumenter
            # This is only really helpful for getting specs to pass.
            @instrumenter.current_trace = nil

            @instrumenter.shutdown
            @instrumenter = nil
          end
        end

        # Check tracing
        def tracing?
          instrumenter && instrumenter.current_trace
        end

        # Start a trace
        def trace(endpoint=nil, cat=nil, title=nil, meta=nil)
          unless instrumenter
            return yield if block_given?
            return
          end

          if block_given?
            instrumenter.trace(endpoint, cat || DEFAULT_CATEGORY, title, nil, meta) { yield }
          else
            instrumenter.trace(endpoint, cat || DEFAULT_CATEGORY, title, nil, meta)
          end
        end

        # Instrument
        def instrument(opts = DEFAULT_OPTIONS, &block)
          unless instrumenter
            return yield if block_given?
            return
          end

          if Hash === opts
            category    = opts[:category] || DEFAULT_CATEGORY
            title       = opts[:title]
            desc        = opts[:description]
            meta        = opts[:meta]
            if opts.key?(:annotations)
              warn "call to #instrument included deprecated annotations"
            end
          else
            category    = DEFAULT_CATEGORY
            title       = opts.to_s
            desc        = nil
            meta        = nil
          end

          instrumenter.instrument(category, title, desc, meta, &block)
        end

        def span_correlation_header(span)
          return unless instrumenter
          instrumenter.span_correlation_header(span)
        end

        # End a span
        def done(span, meta=nil)
          return unless instrumenter
          instrumenter.done(span, meta)
        end

        # Temporarily disable
        def disable
          unless instrumenter
            return yield if block_given?
            return
          end

          instrumenter.disable { yield }
        end

        def config
          return unless instrumenter
          instrumenter.config
        end

      end

    end
  end
end
