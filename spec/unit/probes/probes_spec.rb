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
      expect(subject.is_available?("Skylight")).to be_truthy
      expect(subject.is_available?("Skylight::Probes")).to be_truthy
      expect(subject.is_available?("Nonexistent")).to be_falsey

      expect(subject.is_available?("Skylight::Nonexistent")).to be_falsey
      # For some reason this can behave slightly differently than the previous one in certain
      # versions of Rails. In 2.2.0 they appear to behave identically.
      expect(subject.is_available?("Skylight::Fail")).to be_falsey
    end

    it "installs probe if constant is available" do
      subject.register("Skylight", "skylight", probe)

      expect(probe.install_count).to eq(1)
    end

    it "installs probe on first require" do
      subject.register("SpecHelper::ProbeTestClass", "skylight", probe)

      expect(probe.install_count).to eq(0)

      # HAX: We trick it into thinking that the require 'skylight' loaded ProbeTestClass
      # NOTE: ProbeTestClass is a special class that is automatically removed after specs
      SpecHelper.module_eval "class ProbeTestClass; end"
      require 'skylight'

      expect(probe.install_count).to eq(1)

      # Make sure a second require doesn't install again
      require 'skylight'

      expect(probe.install_count).to eq(1)
    end

    it "does not install probes that are not required or available" do
      subject.register("SpecHelper::ProbeTestClass", "skylight", probe)

      expect(probe.install_count).to eq(0)
    end

    it "does not install probes that are required but remain unavailable" do
      subject.register("SpecHelper::ProbeTestClass", "skylight", probe)

      # Require, but don't create TestClass
      require "skylight"

      expect(probe.install_count).to eq(0)
    end
  end
end
