module SpecHelper
  class TestClock
    def initialize
      @now  = nil
      @skew = 0.0
    end

    def now
      (@now || __now) + @skew
    end

    def now=(v)
      @now = v
    end

    def skip(val)
      @skew += val
    end

    def freeze
      @now = __now
    end

    def unfreeze
      @now = nil
    end

  private

    def __now
      n = Time.now
      n.to_i + n.usec.to_f / 1_000_000
    end
  end

  def clock
    c = Skylight::Util::Clock.default
    c if TestClock === c
  end
end
