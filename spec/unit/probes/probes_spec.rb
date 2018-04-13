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
      register(:skylight, "Skylight", "skylight", probe)

      expect(probe.install_count).to eq(1)
    end

    it "installs probe on first require" do
      register(:probe_test, "SpecHelper::ProbeTestClass", "skylight", probe)

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
      register(:probe_test, "SpecHelper::ProbeTestClass", "skylight", probe)

      expect(probe.install_count).to eq(0)
    end

    it "does not install probes that are required but remain unavailable" do
      register(:probe_test, "SpecHelper::ProbeTestClass", "skylight", probe)

      # Require, but don't create TestClass
      require "skylight"

      expect(probe.install_count).to eq(0)
    end

    it "warns about probes loaded via require" do
      expect(Skylight::DEPRECATOR).to receive(:deprecation_warning).with("Enabling probes via `require` alone", "use `Skylight.probe(:probe_test)` instead")

      # We're not actually requiring here, but since we're bypassing the API it looks like we are
      subject.register(:probe_test, "SpecHelper::ProbeTestClass", "skylight", probe)
    end

    it "does not warn about probes loaded via API" do
      expect(Skylight::DEPRECATOR).to_not receive(:deprecation_warning)

      allow(Skylight::Probes).to receive(:available).and_return({ 'probe_test' => "skylight/probes/probe_test" })
      allow(Skylight::Probes).to receive(:require).with("skylight/probes/probe_test") do |path|
        subject.register(:probe_test, "SpecHelper::ProbeTestClass", "skylight", probe)
      end

      Skylight.probe(:probe_test)
    end

    def register(*args)
      Skylight::DEPRECATOR.silence do
        # This will raise a deprecation warning about require since we're not using `Skylight.probe`
        subject.register(*args)
      end
    end
  end
end
