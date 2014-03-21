unless ENV['SKYLIGHT_DISABLE_AGENT']

module SpecHelper
  class TestClock < Skylight::Util::Clock
    def initialize
      @absolute_secs = nil
      @nanos = nil
      @skew = 0
    end

    def absolute_secs
      (@absolute_secs || __absolute_secs) + @skew / 1_000_000_000
    end

    def nanos
      (@nanos || __nanos) + @skew
    end

    def skip(val)
      @skew += (val * 1_000_000_000).to_i
    end

    def freeze
      @absolute_secs = __absolute_secs
      @nanos = __nanos
    end

    def unfreeze
      @absolute_secs = nil
      @nanos = nil
    end

    def now=(v)
      @nanos = v
    end

  private

    def __absolute_secs
      Time.now.to_i
    end

    def __nanos
      native_hrtime
    end
  end

  def clock
    c = Skylight::Util::Clock.default
    c if TestClock === c
  end
end

end