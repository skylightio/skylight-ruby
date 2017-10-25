module Skylight::Core
  # @api private
  class Middleware

    class BodyProxy
      def initialize(body, &block)
        @body, @block, @closed = body, block, false
      end

      def respond_to?(*args)
        return false if args.first.to_s =~ /^to_ary$/
        super or @body.respond_to?(*args)
      end

      def close
        return if @closed
        @closed = true
        begin
          @body.close if @body.respond_to? :close
        ensure
          @block.call
        end
      end

      def closed?
        @closed
      end

      # N.B. This method is a special case to address the bug described by
      # https://github.com/rack/rack/issues/434.
      # We are applying this special case for #each only. Future bugs of this
      # class will be handled by requesting users to patch their ruby
      # implementation, to save adding too many methods in this class.
      def each(*args, &block)
        @body.each(*args, &block)
      end

      def method_missing(*args, &block)
        super if args.first.to_s =~ /^to_ary$/
        @body.__send__(*args, &block)
      end
    end

    def self.with_after_close(resp, &block)
      # Responses should be finished but in some situations they aren't
      #   e.g. https://github.com/ruby-grape/grape/issues/1041
      if resp.respond_to?(:finish)
        resp = resp.finish
      end

      resp[2] = BodyProxy.new(resp[2], &block)
      resp
    end

    include Util::Logging

    # For Util::Logging
    attr_reader :config

    def initialize(app, opts={})
      @app = app
      @config = opts[:config]
    end

    def instrumentable
      Skylight
    end

    # Allow for overwriting
    def endpoint_name(env)
      "Rack"
    end

    def call(env)
      if env["REQUEST_METHOD"] == "HEAD"
        t { "middleware skipping HEAD" }
        @app.call(env)
      else
        begin
          t { "middleware beginning trace" }
          trace = instrumentable.trace(endpoint_name(env), 'app.rack.request')
          resp = @app.call(env)

          if trace
            Middleware.with_after_close(resp) { trace.submit }
          else
            resp
          end
        rescue Exception
          t { "middleware exception: #{trace}"}
          trace.submit if trace
          raise
        end
      end
    end
  end
end
