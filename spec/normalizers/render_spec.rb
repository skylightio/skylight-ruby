require 'spec_helper'

module Skylight
  describe Normalizers do

    let(:config) do
      Config.new normalizers: { render: { view_paths: %w(/path/to/views) }}
    end

    describe "render_collection.action_view" do

      it "normalizes the notification name" do
        name, title, desc, payload = normalize(identifier: "foo/bar", count: 10)
        name.should == "view.render.collection"
        title.should == "foo/bar"
        desc.should == nil
        payload.should == { count: 10 }
      end

      it "normalizes the title to a relative path" do
        name, title, desc, payload = normalize(config, { identifier: "/path/to/views/foo/bar", count: 10 })
        name.should == "view.render.collection"
        title.should == "foo/bar"
        desc.should == "/path/to/views/foo/bar"
        payload.should == { count: 10 }
      end
    end

    describe "render_template.action_view" do

      it "normalizes the notification name" do
        name, title, desc, payload = normalize(config, identifier: "foo/bar")
        name.should == "view.render.template"
        title.should == "foo/bar"
        desc.should == nil
        payload.should == { partial: false }
      end

      it "normalizes the title to a relative path" do
        name, title, desc, payload = normalize(config, { identifier: "/path/to/views/foo/bar", count: 10 })
        name.should == "view.render.template"
        title.should == "foo/bar"
        desc.should == "/path/to/views/foo/bar"
        payload.should == { partial: false }
      end
    end

    describe "render_partial.action_view" do

      it "normalizes the notification name" do
        name, title, desc, payload = normalize(config, identifier: "foo/bar")
        name.should == "view.render.template"
        title.should == "foo/bar"
        desc.should == nil
        payload.should == { partial: true }
      end

      it "normalizes the title to a relative path" do
        name, title, desc, payload = normalize(config, { identifier: "/path/to/views/foo/bar", count: 10 })
        name.should == "view.render.template"
        title.should == "foo/bar"
        desc.should == "/path/to/views/foo/bar"
        payload.should == { partial: true }
      end
    end
  end
end
