require "spec_helper"

module Skylight
  describe Subscriber do
    let(:config) { Config.new(foo: "hello", root: root, log_level: :fatal) }
    let(:subscriber) { Subscriber.new(config, trace.instrumenter) }

    let(:source_file) { config.root.join("source-file.rb").to_s }
    let(:caller_location) { double(absolute_path: source_file, lineno: 1) }

    before do
      allow(subscriber).to receive(:raise_on_error?) { false }
      allow_any_instance_of(Skylight::Extensions::SourceLocation).to receive(:find_caller) { caller_location }
    end

    class Skylight::Normalizers::SubscriberTestNormalizer < Skylight::Normalizers::Normalizer
      register "subscriber_test.spec.skylight"

      def normalize(*)
        ["spec.skylight", "normalized", nil]
      end
    end

    class Skylight::Normalizers::CustomSourceLocationNormalizer < Skylight::Normalizers::Normalizer
      register "subscriber_test_source_location.spec.skylight"

      def normalize(trace, *)
        ["spec_source_location.skylight", "normalized", nil, { source_location: source_location(trace) }]
      end

      def source_location(trace, *, **)
        [trace.config.root.join("custom_path.rb").to_s, 123]
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

    it "instruments" do
      trace.instrumenter.extensions.enable!(:source_location)

      ActiveSupport::Notifications.instrument("subscriber_test.spec.skylight") do
        ActiveSupport::Notifications.instrument("subscriber_test_source_location.spec.skylight") do
          # empty
        end
      end

      expect(trace.test_spans).to contain_exactly(
        {
          id:        1,
          done:      true,
          done_meta: {},
          args:      [
            "spec.skylight",
            "normalized",
            nil,
            { source_file: source_file, source_line: 1 }
          ]
        },
        { # rubocop:disable Style/BracesAroundHashParameters
          id:        2,
          done:      true,
          done_meta: {},
          args:      [
            "spec_source_location.skylight",
            "normalized",
            nil,
            { source_file: root.join("custom_path.rb").to_s, source_line: 123 }
          ]
        }
      )
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
