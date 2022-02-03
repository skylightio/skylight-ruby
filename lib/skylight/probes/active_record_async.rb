module Skylight
  module Probes
    module ActiveRecord
      module FutureResult
        # Applied to ActiveSupport::Notifications::Event
        module AsyncEventExtensions
          # Notify Skylight that the event has started
          def __sk_start!
            subscriber = Skylight.instrumenter.subscriber
            subscriber.start(name, nil, payload)
            trace = Skylight.instrumenter.current_trace

            # Set a finisher to end the event
            @__sk_finisher = ->(name, payload) do
              subscriber.with_trace(trace) { subscriber.finish(name, nil, payload) }
            end

            # End it immediately if we've actually already ended
            __sk_finish! if @end
          rescue StandardError => e
            Skylight.error("Unable to start event for FutureResult: #{e}")
          end

          # Notify Skylight that the event has finished
          def __sk_finish!
            return unless @__sk_finisher

            @__sk_finisher.call(name, payload)
            @__sk_finisher = nil
          rescue StandardError => e
            Skylight.error("Unable to finish event for FutureResult: #{e}")
          end

          # When the event is marked as finish make sure we notify Skylight
          def finish!
            super
            __sk_finish!
          end
        end

        # Applied to FutureResult
        module Instrumentation
          def result(*, **)
            # This instruments the whole FutureResult so that we know when we were executing (potenially) async.
            ActiveSupport::Notifications.instrument("future_result.active_record", { args: @args, kwargs: @kwargs }) do
              super
            end
          end

          private

          def execute_or_wait(*, **)
            # At this point we're actually waiting for the query to have finished executing.

            begin
              # If the query has already started async, the @event_buffer will be defined.
              # We grab the events (currently only the SQL queries), extend them with our
              # special methods and notify Skylight.
              # We act as if the event has just stared, though the query may already have been
              # running. This means we're essentially just logging blocking time right now.

              # Dup here just in case more get added somehow during the super call
              events = @event_buffer&.instance_variable_get(:@events).dup

              events&.each do |event|
                event.singleton_class.prepend(AsyncEventExtensions)
                event.__sk_start!
              end
            rescue StandardError => e
              Skylight.error("Unable to start events for FutureResult: #{e}")
            end

            super
          ensure
            # Once we've actually got a result, we mark each one as finished.
            # Note that it may have already finished, but if it didn't we need to say so now.
            events&.reverse_each(&:__sk_finish!)
          end
        end

        class Probe
          def install
            ::ActiveRecord::FutureResult.prepend(Instrumentation)
          end
        end
      end
    end

    register(
      :active_record_async,
      "ActiveRecord::FutureResult",
      "active_record/future_result",
      ActiveRecord::FutureResult::Probe.new
    )
  end
end
