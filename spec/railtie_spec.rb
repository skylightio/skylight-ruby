require 'spec_helper'

# Not sure if this should be a unit test or just get
# covered as part of integration tests
# - Peter

module Skylight
  describe Railtie do
    let :railtie do
      # Not sure this is the correct way
      Railtie.send(:new)
    end

    it "has a default config" do
      railtie.config.should be_an_instance_of(Config)
    end

    it "can use a custom config" do
      new_config = Config.new
      railtie.config = new_config
      railtie.config.should == new_config
    end

    it "sets up an instrumenter with the config" do
      railtie.instrumenter.should be_an_instance_of(Instrumenter)
      railtie.instrumenter.config.should == railtie.config
    end

  end
end
