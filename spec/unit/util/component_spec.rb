require "spec_helper"

describe Skylight::Util::Component do
  def stub_program_name(name)
    allow_any_instance_of(described_class).to receive(:program_name) { name }
  end

  let(:config) do
    Config.new
  end

  let(:env) { nil }
  let(:name) { nil }
  let(:component) { described_class.new(env, name) }

  context "default" do
    specify do
      expect(component.to_s).to eq("web:production")
      expect(component).to be_web
    end
  end

  context "given env" do
    let(:env) { "staging" }

    specify do
      expect(component.to_s).to eq("web:staging")
      expect(component).to be_web
    end
  end

  context "given name" do
    let(:name) { "component-name" }

    specify do
      expect(component.to_s).to eq("component-name:production")
      expect(component).to be_worker
    end
  end

  context "invalid given name" do
    let(:name) { "hello, world!" }

    specify do
      expect { component.to_s }.to raise_error(ArgumentError)
    end
  end
end
