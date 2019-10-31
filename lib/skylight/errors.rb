require "json"

module Skylight
  # @api private
  class ConfigError < RuntimeError; end

  class NativeError < StandardError
    @classes = {}

    def self.register(code, name, message)
      if @classes.key?(code)
        raise "Duplicate error class code: #{code}; name=#{name}"
      end

      Skylight.module_eval <<-RUBY, __FILE__, __LINE__ + 1
        class #{name}Error < NativeError
          def self.code; #{code}; end
          def self.message; #{message.to_json}; end
        end
      RUBY

      klass = Skylight.const_get("#{name}Error")

      @classes[code] = klass
    end

    def self.for_code(code)
      @classes[code] || self
    end

    attr_reader :method_name

    def self.code
      9999
    end

    def self.message
      "Encountered an unknown internal error"
    end

    def initialize(method_name)
      @method_name = method_name
      super(format("[E%<code>04d] %<message>s [%<meth>s]", code: code, message: message, meth: method_name))
    end

    def code
      self.class.code
    end

    def formatted_code
      format("%04d", code)
    end

    # E0003
    register(3, "MaximumTraceSpans", "Exceeded maximum number of spans in a trace.")

    # E0004
    register(4, "SqlLex", "Failed to lex SQL query.")

    # E0005
    register(5, "InstrumenterUnrecoverable", "Instrumenter is not running.")
  end
end
