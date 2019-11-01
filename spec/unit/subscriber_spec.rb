require "spec_helper"

module Skylight
  describe Subscriber do
    class FakeTrace
      def instrument(*)
        @span_counter ||= 0
        @span_counter += 1
      end

      def notifications
        @notifications ||= []
      end

      def done(*); end
    end

    FakeInstrumenter = Struct.new(:current_trace) do
      def disabled?
        false
      end
    end

    let(:instrumenter) do
      FakeInstrumenter.new(trace)
    end

    let(:trace) { FakeTrace.new }

    let(:config) { Config.new(foo: "hello") }
    let(:subscriber) { Subscriber.new(config, instrumenter) }

    before { allow(subscriber).to receive(:raise_on_error?) { false } }

    class Skylight::Normalizers::SubscriberTestNormalizer < Skylight::Normalizers::Normalizer
      register "subscriber_test.spec.skylight"

      def normalize(*)
        ["spec.skylight", "normalized", nil]
      end
    end

    class Skylight::Normalizers::SubscriberTestFailureNormalizer < Skylight::Normalizers::Normalizer
      register "normalizer_failure.spec.skylight"

      def normalize(*)
        raise "something went wrong"
      end
    end

    around do |ex|
      subscriber.register!
      ex.call
      subscriber.unregister!
    end

    def count_sk_subscribers(collection = all_asn_subscribers)
      collection.count do |subscriber|
        subscriber.instance_variable_get(:@delegate).is_a?(Skylight::Subscriber)
      end
    end

    def all_asn_subscribers
      ActiveSupport::Notifications.notifier.instance_exec do
        @subscribers ||
          # Rails > 6.0.0.beta1
          (@other_subscribers + @string_subscribers.values).flatten
      end
    end

    let(:unsub_key) { "render.active_model_serializers" }

    specify("unsubscribing from a string does not unsub from everything") do
      original_count = count_sk_subscribers

      # Note: do not want to rely on a specific count here (as of this writing,
      # actual count is 29); it should just be some number greater than 1
      # (ensure that we're not unsubscribing *all* skylight listeners)
      expect(original_count).to be > 1

      expect do
        ActiveSupport::Notifications.unsubscribe(unsub_key)
      end.to change {
        count_sk_subscribers(ActiveSupport::Notifications.notifier.listeners_for(unsub_key))
      }.from(1).to(0)

      expect(count_sk_subscribers).to eq(original_count - 1)
    end

    context "evented error handling" do
      specify "notifications are pushed even on errors" do
        ActiveSupport::Notifications.instrument("subscriber_test.spec.skylight") do
          expect(trace.notifications.count).to eq(1)
          expect(trace.notifications.first.name).to eq("subscriber_test.spec.skylight")

          ActiveSupport::Notifications.instrument("normalizer_failure.spec.skylight") do
            expect(trace.notifications.map(&:span)).to eq([1, nil])
          end

          expect(trace.notifications.count).to eq(1)
          expect(trace.notifications.first.name).to eq("subscriber_test.spec.skylight")
        end

        expect(trace.notifications.count).to eq(0)
      end
    end
  end
end
