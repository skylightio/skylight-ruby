module Skylight
  module Metrics
    class ProcessCpuGauge

      def initialize(cache_for = 5, clock = Util::Clock.default)
        @value = nil
        @cache_for = cache_for
        @last_check_at = 0
        @clock = clock

        @last_totaltime = nil
        @last_usagetime = nil
        @last_utime = nil
        @last_stime = nil
      end

      def call(now = @clock.absolute_secs)
        if !@value || should_check?(now)
          @value = check
          @last_check_at = now
        end

        @value
      end

    private

      def check
        ret = nil

        statfile = "/proc/stat"
        pidstatfile = "/proc/#{Process.pid}/stat"

        if File.exist?(statfile) && File.exist?(pidstatfile)
          cpustats = File.readlines(statfile).grep(/^cpu /).first.split(' ')
          usagetime = cpustats[1..3].reduce(0){|sum, i| sum + i.to_i }
          totaltime = usagetime + cpustats[4].to_i

          pidstats = File.read(pidstatfile).split(' ')
          utime, stime = pidstats[13].to_i, pidstats[14].to_i

          if @last_totaltime && @last_usagetime && @last_utime && @last_stime
            elapsed = totaltime - @last_totaltime
            ret = [(usagetime - @last_usagetime).to_f / elapsed,
                   (utime - @last_utime).to_f / elapsed,
                   (stime - @last_stime).to_f / elapsed]
          end

          @last_totaltime = totaltime
          @last_usagetime = usagetime
          @last_utime = utime
          @last_stime = stime
        end

        ret
      rescue Errno::ENOENT
        nil
      end

      def should_check?(now)
        now >= @last_check_at + @cache_for
      end
    end
  end
end
