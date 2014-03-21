module SpecHelper
  class TestClock < Skylight::Util::Clock
    def initialize
      @absolute_secs = nil
      @tick = nil
      @skew = 0
    end

    def absolute_secs
      (@absolute_secs || __absolute_secs) + @skew / 1_000_000_000
    end

    def tick
      (@tick || __tick) + @skew
    end

    def skip(val)
      @skew += (val * 1_000_000_000).to_i
    end

    def freeze
      @absolute_secs = __absolute_secs
      @tick = __tick
    end

    def unfreeze
      @absolute_secs = nil
      @tick = nil
    end

    def now=(v)
      @tick = v
    end

  private

    def __absolute_secs
      Time.now.to_i
    end

    def __tick
      native_hrtime
    end
  end

  def clock
    c = Skylight::Util::Clock.default
    c if TestClock === c
  end
end
