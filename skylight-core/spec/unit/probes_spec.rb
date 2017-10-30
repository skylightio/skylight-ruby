require 'spec_helper'

# Tested here because we need native
module Skylight::Core

  describe "Probes", :probes, :agent do

    before :all do
      @require_hooks    = Probes.require_hooks.dup
      @installed_probes = Probes.installed.dup
    end

    after :each do
      Probes.require_hooks.replace(@require_hooks)
      Probes.installed.replace(@installed_probes)
    end

    let(:probe) { create_probe }

    subject { Probes }

    it "can determine const availability" do
      expect(subject.is_available?("Skylight::Core")).to be_truthy
      expect(subject.is_available?("Skylight::Core::Probes")).to be_truthy
      expect(subject.is_available?("Nonexistent")).to be_falsey

      expect(subject.is_available?("Skylight::Nonexistent")).to be_falsey
      expect(subject.is_available?("Skylight::Fail")).to be_falsey
    end

    it "installs probe if constant is available" do
      subject.register("Skylight::Core", "skylight/core", probe)

      expect(probe.install_count).to eq(1)
    end

    it "installs probe on first require" do
      subject.register("SpecHelper::ProbeTestClass", "skylight/core", probe)

      expect(probe.install_count).to eq(0)

      # HAX: We trick it into thinking that the require 'skylight/core' loaded ProbeTestClass
      # NOTE: ProbeTestClass is a special class that is automatically removed after specs
      SpecHelper.module_eval "class ProbeTestClass; end"
      require 'skylight/core'

      expect(probe.install_count).to eq(1)

      # Make sure a second require doesn't install again
      require 'skylight/core'

      expect(probe.install_count).to eq(1)
    end

    it "does not install probes that are not required or available" do
      subject.register("SpecHelper::ProbeTestClass", "skylight/core", probe)

      expect(probe.install_count).to eq(0)
    end

    it "does not install probes that are required but remain unavailable" do
      subject.register("SpecHelper::ProbeTestClass", "skylight/core", probe)

      # Require, but don't create TestClass
      require "skylight/core"

      expect(probe.install_count).to eq(0)
    end
  end
end
