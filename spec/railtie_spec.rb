require 'spec_helper'

# Not sure if this should be a unit test or just get
# covered as part of integration tests
# - Peter

module Skylight
  describe Railtie do
    let :railtie do
      # Not sure this is the correct way
      Railtie
    end

    it "has a default set of run environments" do
      railtie.config.skylight.environments.should == ['production']
    end

    it "has a default config path" do
      railtie.config.skylight.config_path.should == "config/skylight.yml"
    end

    it "sets up an instrumenter with the config" do
      railtie.instrumenter.should be_an_instance_of(Instrumenter)
    end

  end
end
