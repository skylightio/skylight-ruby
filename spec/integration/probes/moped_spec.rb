require 'spec_helper'

# Requires mongodb instance to be running
if ENV['TEST_MONGO_INTEGRATION']
  describe 'Mongo integration with Moped', :moped_probe, :instrumenter do

    def build_session(opts={})
      @session = Moped::Session.new([ "localhost:27017" ], opts)
      @session.use "echo_test"
      @session
    end

    it "instruments without affecting default instrumenter" do
      expect(current_trace).to receive(:instrument).with("db.mongo.query", "INSERT artists", nil).and_call_original.once
      expect(Moped::Loggable).to receive(:log_operations).at_least(:once)

      session = build_session
      session[:artists].insert(name: "Peter")
    end

    context "when instrument is already AS::N" do

      it "instruments only once" do
        # One command to initialize one for actual insert
        expect(ActiveSupport::Notifications).to receive(:instrument).and_call_original.twice

        session = build_session(instrumenter: ActiveSupport::Notifications)
        session[:artists].insert(name: "Peter")
      end

    end

  end
end