module Skylight
  class NativeError < StandardError

    @@classes = { }

    def self.register(code, name, message)
      if @@classes.has_key?(code)
        raise "Duplicate error class code: #{code}; name=#{name}"
      end

      Skylight.module_eval <<-ruby
        class #{name}Error < NativeError
          def self.code; #{code}; end
          def self.message; #{message.to_json}; end
        end
      ruby

      klass = Skylight.const_get("#{name}Error")

      @@classes[code] = klass
    end

    def self.for_code(code)
      @@classes[code] || self
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
      super(sprintf("[E%04d] %s [%s]", code, message, method_name))
    end

    def code
      self.class.code
    end

    def formatted_code
      "%04d" % code
    end

    # E0003
    register(3, "MaximumTraceSpans", "Exceeded maximum number of spans in a trace.")

    # E0004
    register(4, "SqlLex", "Failed to lex SQL query.")
  end

end
