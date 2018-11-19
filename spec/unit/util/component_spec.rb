require "spec_helper"

describe Skylight::Util::Component do
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

  context "rails server forces web" do
    before do
      allow_any_instance_of(described_class).to receive(:rails_server?) { true }
    end

    let(:name) { "impossible-name" }

    specify do
      expect(component.to_s).to eq("web:production")
      expect(component).to be_web
    end
  end

  describe "inferred rake-task workers" do
    let(:rake) { "/home/my_user/bin/rake" }
    [
      "resque:work",
      "resque:worker",
      "backburner:work",
      "jobs:work",
      "qu:work",
      "que:work",
      "qc:work",
      "sneakers:work"
    ].each do |args|
      context "rake: #{args}" do
        before do
          allow_any_instance_of(described_class).to receive_messages(
            program_name: rake,
            argv: [args]
          )
        end

        specify do
          expect(component.to_s).to eq("worker:production")
          expect(component).to be_worker
        end

        context "with name override" do
          let(:name) { args.sub(":", "-") }
          specify do
            expect(component.to_s).to eq("#{name}:production")
            expect(component).to be_worker
          end
        end
      end
    end
  end
end
