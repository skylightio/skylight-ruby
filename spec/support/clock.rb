module SpecHelper
  class TestClock < Skylight::Util::Clock
    def initialize
      @now  = nil
      @skew = 0
    end

    def micros
      (@now || __micros) + @skew
    end

    def skip(val)
      @skew += (val * 1_000_000).to_i
    end

    def freeze
      @now = __micros
    end

    def unfreeze
      @now = nil
    end

    def now=(v)
      @now = v
    end

  private

    def __micros
      n = Time.now
      n.to_i * 1_000_000 + n.usec
    end
  end

  def clock
    c = Skylight::Util::Clock.default
    c if TestClock === c
  end
end
