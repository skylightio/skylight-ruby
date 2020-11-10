require "spec_helper"

module Skylight
  describe Normalizers do
    before :each do
      @original_registry = Normalizers.instance_variable_get(:@registry)

      stub_const("TestNormalizer", Class.new(Normalizers::Normalizer) do
        register "basic.test"
      end)

      stub_const("DisabledNormalizer", Class.new(Normalizers::Normalizer) do
        register "disabled.test", enabled: false
      end)
    end

    after :each do
      Normalizers.instance_variable_set(:@registry, @original_registry)
    end

    it "registers normalizers" do
      expect(subject.registry["basic.test"]).to eq([TestNormalizer, true])
      expect(subject.registry["disabled.test"]).to eq([DisabledNormalizer, false])
    end

    it "can enable a disabled normalizer" do
      Normalizers.enable("disabled.test")
      expect(subject.registry["disabled.test"][1]).to eq(true)
    end

    it "can enable a disabled normalizer by partial match" do
      Normalizers.enable("test")
      expect(subject.registry["disabled.test"][1]).to eq(true)
    end

    it "will not enable a bad match" do
      %w[tes est disabled].each do |key|
        expect do
          Normalizers.enable(key)
        end.to raise_error(ArgumentError, "no normalizers match #{key}")
      end

      expect(subject.registry["disabled.test"][1]).to eq(false)
    end
  end
end
