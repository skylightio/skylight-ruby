require "spec_helper"

module Skylight::Core
  describe Subscriber do
    let(:config) { Config.new(foo: "hello") }
    let(:subscriber) { Subscriber.new(config, Object.new) }

    around do |ex|
      subscriber.register!
      ex.call
      subscriber.unregister!
    end

    def count_sk_subscribers(collection = all_asn_subscribers)
      collection.count do |subscriber|
        subscriber.instance_variable_get(:@delegate).is_a?(Skylight::Core::Subscriber)
      end
    end

    def all_asn_subscribers
      ActiveSupport::Notifications.notifier.instance_variable_get(:@subscribers)
    end

    let(:unsub_key) { "render.active_model_serializers" }

    specify("unsubscribing from a string does not unsub from everything") do
      original_count = count_sk_subscribers

      # Note: do not want to rely on a specific count here (as of this writing,
      # actual count is 29); it should just be some number greater than 1
      # (ensure that we're not unsubscribing *all* skylight listeners)
      expect(original_count).to be > 1

      expect {
        ActiveSupport::Notifications.unsubscribe(unsub_key)
      }.to change {
        count_sk_subscribers(ActiveSupport::Notifications.notifier.listeners_for(unsub_key))
      }.from(1).to(0)

      expect(count_sk_subscribers).to eq(original_count - 1)
    end
  end
end
