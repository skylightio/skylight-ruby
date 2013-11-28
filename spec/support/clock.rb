module SpecHelper
  class TestClock < Skylight::Util::Clock
    def initialize
      @now  = nil
      @skew = 0
    end

    def nanos
      (@now || __nanos) + @skew
    end

    def skip(val)
      @skew += (val * 1_000_000_000).to_i
    end

    def freeze
      @now = __nanos
    end

    def unfreeze
      @now = nil
    end

    def now=(v)
      @now = v
    end

  private

    def __nanos
      native_hrtime
    end
  end

  def clock
    c = Skylight::Util::Clock.default
    c if TestClock === c
  end
end
