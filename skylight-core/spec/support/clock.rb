module SpecHelper

  class TestClock < Skylight::Core::Util::Clock
    alias __tick tick

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

    def tick=(v)
      @tick = v
    end

  private

    def __absolute_secs
      Time.now.to_i
    end
  end

  def mock_clock!
    return if Skylight::Core::Util::Clock.default.is_a?(TestClock)
    Skylight::Core::Util::Clock.default = TestClock.new
  end

  def reset_clock!
    Skylight::Core::Util::Clock.default = Skylight::Core::Util::Clock.new
  end

  def clock
    c = Skylight::Core::Util::Clock.default
    c if TestClock === c
  end
end
