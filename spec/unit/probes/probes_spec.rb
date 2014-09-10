require 'spec_helper'

module Skylight

  describe "Probes", :probes, :agent do

    before :all do
      @require_hooks    = Skylight::Probes.require_hooks.dup
      @installed_probes = Skylight::Probes.installed.dup
    end

    after :each do
      Skylight::Probes.require_hooks.replace(@require_hooks)
      Skylight::Probes.installed.replace(@installed_probes)
    end

    let(:probe) { create_probe }

    subject { Skylight::Probes }

    it "can determine const availability" do
      subject.is_available?("Skylight").should be_truthy
      subject.is_available?("Skylight::Probes").should be_truthy
      subject.is_available?("Nonexistent").should be_falsey
      subject.is_available?("Skylight::Nonexistent").should be_falsey
    end

    it "installs probe if constant is available" do
      subject.register("Skylight", "skylight", probe)

      probe.install_count.should == 1
    end

    it "installs probe on first require" do
      subject.register("SpecHelper::ProbeTestClass", "skylight", probe)

      probe.install_count.should == 0

      # HAX: We trick it into thinking that the require 'skylight' loaded ProbeTestClass
      # NOTE: ProbeTestClass is a special class that is automatically removed after specs
      SpecHelper.module_eval "class ProbeTestClass; end"
      require 'skylight'

      probe.install_count.should == 1

      # Make sure a second require doesn't install again
      require 'skylight'

      probe.install_count.should == 1
    end

    it "does not install probes that are not required or available" do
      subject.register("SpecHelper::ProbeTestClass", "skylight", probe)

      probe.install_count.should == 0
    end

    it "does not install probes that are required but remain unavailable" do
      subject.register("SpecHelper::ProbeTestClass", "skylight", probe)

      # Require, but don't create TestClass
      require "skylight"

      probe.install_count.should == 0
    end
  end
end
