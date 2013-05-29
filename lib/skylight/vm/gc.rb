
module Skylight
  module VM
    if defined?(JRUBY_VERSION)

      # This doesn't quite work as we would like it. I believe that the GC
      # statistics includes time that is not stop-the-world, this does not
      # necessarily take time away from the application.
      #
      # require 'java'
      # class GC
      #   def initialize
      #     @factory = Java::JavaLangManagement::ManagementFactory
      #   end
      #
      #   def enable
      #   end
      #
      #   def total_time
      #     res = 0.0
      #
      #     @factory.garbage_collector_mx_beans.each do |mx|
      #       res += (mx.collection_time.to_f / 1_000.0)
      #     end
      #
      #     res
      #   end
      # end

    elsif defined?(::GC::Profiler)

      class GC
        def initialize
          @total = 0.0
        end

        def enable
          ::GC::Profiler.enable
        end

        def total_time
          run = ::GC::Profiler.total_time

          if run > 0
            ::GC::Profiler.clear
          end

          @total += run
        end
      end

    end

    # Fallback
    unless defined?(VM::GC)

      class GC
        def enable
        end

        def total_time
          0.0
        end
      end

    end
  end
end
