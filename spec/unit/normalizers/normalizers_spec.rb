require 'spec_helper'

module Skylight
  describe Normalizers do

    before :each do
      @original_registry = Skylight::Normalizers.instance_variable_get(:@registry)

      class ::TestNormalizer < Normalizers::Normalizer
        register "basic.test"
      end

      class ::DisabledNormalizer < Normalizers::Normalizer
        register "disabled.test", enabled: false
      end
    end

    after :each do
      Skylight::Normalizers.instance_variable_set(:@registry, @original_registry)

      Object.send(:remove_const, :TestNormalizer)
      Object.send(:remove_const, :DisabledNormalizer)
    end

    it "registers normalizers" do
      expect(subject.registry["basic.test"]).to eq([TestNormalizer, true])
      expect(subject.registry["disabled.test"]).to eq([DisabledNormalizer, false])
    end

    it "can enable a disabled normalizer" do
      Skylight::Normalizers.enable("disabled.test")
      expect(subject.registry["disabled.test"][1]).to eq(true)
    end

    it "can enable a disabled normalizer by partial match" do
      Skylight::Normalizers.enable("test")
      expect(subject.registry["disabled.test"][1]).to eq(true)
    end

    it "will not enable a bad match" do
      ["tes", "est", "disabled"].each do |key|
        expect {
          Skylight::Normalizers.enable(key)
        }.to raise_error(ArgumentError, "no normalizers match #{key}")
      end

      expect(subject.registry["disabled.test"][1]).to eq(false)
    end

    it "warns when building a disabled normalizer" do
      expect(Skylight::DEPRECATOR).to receive(:deprecation_warning).
        with("Enabling non-default normalizers via `require`",
              "use `Skylight.enable_normalizer('disabled.test')` instead")

      config = {}
      Skylight::Normalizers.build(config)
    end

    it "doesn't warn when building if normalizers are enabled" do
      expect(Skylight::DEPRECATOR).to_not receive(:deprecation_warning)

      Skylight::Normalizers.enable("disabled.test")

      config = {}
      Skylight::Normalizers.build(config)
    end

  end
end
