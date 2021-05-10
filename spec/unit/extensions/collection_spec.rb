require "spec_helper"

describe Skylight::Extensions::Collection do
  let(:config) { OpenStruct.new }
  let(:collection) { described_class.new(config) }

  describe "#allowed_meta_keys" do
    specify { expect(collection.allowed_meta_keys).to eq([]) }

    context "with source_location enabled" do
      specify do
        collection.enable!(:source_location)
        expect(collection.allowed_meta_keys).to eq(%i[source_location source_file source_line])
      end
    end

    context "with source_location disabled" do
      specify do
        collection.enable!(:source_location)
        expect { collection.disable!(:source_location) }.to change { collection.allowed_meta_keys }.from(
          %i[source_location source_file source_line]
        ).to([])
      end
    end
  end
end
