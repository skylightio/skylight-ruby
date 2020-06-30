require "skylight/extensions"

module SpecHelper
  class MockInstrumenter
    attr_accessor :current_trace
    attr_reader :config

    def initialize(config, current_trace: nil)
      @config = config
      @current_trace = current_trace
    end

    def disabled?
      false
    end

    def extensions
      @extensions ||= Skylight::Extensions::Collection.new(@config)
    end
  end

  class MockTrace
    attr_accessor :endpoint, :segment
    attr_reader :instrumenter

    def initialize(instrumenter = nil)
      @instrumenter = instrumenter
      @endpoint = "Rack"
    end

    def config
      instrumenter.config
    end

    def instrument(*args)
      id = test_spans.length + 1
      test_spans << { id: id, done: false, args: args }
      id
    end

    # Not in the real API
    def test_spans
      @test_spans ||= []
    end

    def notifications
      @notifications ||= []
    end

    def done(span, meta = nil)
      span = test_spans.find { |s| s[:id] == span }
      raise "missing span" unless span

      span[:done] = true
      span[:done_meta] = meta

      nil
    end
  end

  def instrumenter
    # NOTE: `config` is defined in spec/support/helpers.rb
    @instrumenter ||= MockInstrumenter.new(config)
  end

  def trace
    @trace ||= (instrumenter.current_trace = MockTrace.new(instrumenter))
  end
end
