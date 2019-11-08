module SpecHelper
  class MockInstrumenter
    attr_accessor :current_trace

    def initialize(current_trace: nil)
      @current_trace = current_trace
    end

    def disabled?
      false
    end

    def instance_method_source_location(*)
      nil
    end

    def find_caller(*)
      nil
    end
  end

  class MockTrace
    attr_accessor :endpoint, :segment

    def initialize
      @endpoint = "Rack"
    end

    def instrumenter
      @instrumenter ||= MockInstrumenter.new(current_trace: self)
    end

    def instrument(*)
      @span_counter ||= 0
      @span_counter += 1
    end

    def notifications
      @notifications ||= []
    end

    def done(*); end
  end

  def trace
    @trace ||= MockTrace.new
  end
end
