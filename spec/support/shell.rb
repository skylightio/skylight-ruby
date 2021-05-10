$LOAD_PATH.unshift File.expand_path("../../lib/skylight/vendor/cli", __dir__)
require "thor"

module SpecHelpers
  class TestStdout
    attr_reader :queue

    def initialize(shell)
      @shell = shell
    end

    def print(buffer)
      current_line << buffer
    end

    def flush
      @shell.test_line(@current_line).tap { @current_line = "" }
    end

    def current_line
      @current_line ||= ""
    end

    def puts(value)
      print(value)
      flush
    end

    def printf(*args)
      puts sprintf(*args)
    end
  end

  class TestShell < Thor::Shell::Basic
    attr_reader :expectations

    def initialize(expectations, &block)
      @expector = block
      @expectations = expectations.to_enum
      super()
    end

    def test_line(line)
      puts "[OUT]: #{line.inspect}" if ENV["DEBUG"]
      return if line.strip.empty?

      out, reply = Array(expectations.next)
      @expector.call(line.strip, out)

      # raise 'no match' unless out === line
      puts "[IN]: #{reply}" if reply && ENV["DEBUG"]
      reply
    rescue StopIteration
      raise "expectation list ended before output did; out=#{line.inspect}"
    end

    def stdout
      @stdout ||= TestStdout.new(self)
    end

    def ask_simply(statement, _color = nil, options = {})
      default = options[:default]
      message = [statement, ("(#{default})" if default), nil].uniq.join(" ")
      result = readline(message, options)

      return unless result

      result = result.to_s.strip

      default && result == "" ? default : result
    end

    private

    def readline(message, _options)
      test_line(message) || raise("no reply from readline; prompt=#{message.inspect}")
    end
  end
end
