require 'spec_helper'

shared_context "normalizer" do
  let(:trace) { Struct.new(:endpoint).new }

  def normalize(payload)
    name = self.class.metadata[:example_group][:description_args][1]
    Skylight::Normalize.normalize(trace, name, payload)
  end
end

module Skylight
  describe Normalize, "render_collection.action_view" do
    include_context "normalizer"

    it "normalizes the notification name" do
      name, title, desc, payload = normalize(identifier: "foo/bar", count: 10)
      name.should == "view.render.collection"
      title.should == "foo/bar"
      desc.should == "foo/bar"
      payload.should == { count: 10 }
    end
  end

  describe Normalize, "render_template.action_view" do
    include_context "normalizer"

    it "normalizes the notification name" do
      name, title, desc, payload = normalize(identifier: "foo/bar")
      name.should == "view.render.template"
      title.should == "foo/bar"
      desc.should == "foo/bar"
      payload.should == { partial: false }
    end
  end
end

