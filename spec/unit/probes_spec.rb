require "spec_helper"

# Tested here because we need native
module Skylight
  describe "Probes", :probes, :agent do
    before :each do
      @registered       = Probes.registered.dup
      @require_hooks    = Probes.require_hooks.dup
      @installed_probes = Probes.installed.dup
      Probes.registered.clear
      Probes.require_hooks.clear
      Probes.installed.clear
    end

    after :each do
      Probes.registered.replace(@registered)
      Probes.require_hooks.replace(@require_hooks)
      Probes.installed.replace(@installed_probes)
    end

    let(:probe) { create_probe }

    subject { Probes }

    it "can determine const availability" do
      expect(subject.constant_available?("Skylight")).to be_truthy
      expect(subject.constant_available?("Skylight::Probes")).to be_truthy
      expect(subject.constant_available?("Nonexistent")).to be_falsey

      expect(subject.constant_available?("Skylight::Nonexistent")).to be_falsey
      expect(subject.constant_available?("Skylight::Fail")).to be_falsey
    end

    it "installs probe if constant is available" do
      register(:skylight, "Skylight", "skylight", probe)
      Probes.install!

      expect(probe.install_count).to eq(1)
    end

    it "installs probe on first require" do
      register(:probe_test, "SpecHelper::ProbeTestClass", "skylight", probe)
      Probes.install!

      expect(probe.install_count).to eq(0)

      # HAX: We trick it into thinking that the require 'skylight' loaded ProbeTestClass
      # NOTE: ProbeTestClass is a special class that is automatically removed after specs
      SpecHelper.module_eval "class ProbeTestClass; end", __FILE__, __LINE__
      require "skylight"

      expect(probe.install_count).to eq(1)

      # Make sure a second require doesn't install again
      require "skylight"

      expect(probe.install_count).to eq(1)
    end

    it "installs all probes registered on the same path" do
      register(:probe_test, "SpecHelper::ProbeTestClass", "skylight", probe)
      register(:probe_test_aux, "SpecHelper::ProbeTestAuxClass", "skylight", probe)
      Probes.install!

      expect(probe.install_count).to eq(0)

      # HAX: We trick it into thinking that the require 'skylight' loaded ProbeTestClass
      # NOTE: ProbeTestClass is a special class that is automatically removed after specs
      SpecHelper.module_eval "class ProbeTestClass; end", __FILE__, __LINE__
      SpecHelper.module_eval "class ProbeTestAuxClass; end", __FILE__, __LINE__
      require "skylight"

      expect(probe.install_count).to eq(2)

      # Make sure a second require doesn't install again
      require "skylight"

      expect(probe.install_count).to eq(2)
    end

    it "does not install probes that are not required or available" do
      register(:probe_test, "SpecHelper::ProbeTestClass", "skylight", probe)
      Probes.install!

      expect(probe.install_count).to eq(0)
    end

    it "does not install probes that are required but remain unavailable" do
      register(:probe_test, "SpecHelper::ProbeTestClass", "skylight", probe)
      Probes.install!

      # Require, but don't create TestClass
      require "skylight"

      expect(probe.install_count).to eq(0)
    end

    it "logs error on installation failure" do
      SpecHelper.module_eval "class ProbeTestClass; end", __FILE__, __LINE__
      register(:probe_test, "SpecHelper::ProbeTestClass", "skylight", probe)

      allow(probe).to receive(:install).and_raise(StandardError, "aaaahhh!!!")
      expect($stderr).to receive(:puts) do |error|
        expect(error).to include("Encountered an error while installing the probe for SpecHelper::ProbeTestClass.")
        expect(error).to include("ERROR: StandardError: aaaahhh!!!")
      end

      expect { Probes.install! }.not_to raise_error
    end

    def register(*args)
      Skylight::DEPRECATOR.silence do
        # This will raise a deprecation warning about require since we're not using `Skylight.probe`
        subject.register(*args)
      end
    end
  end
end
