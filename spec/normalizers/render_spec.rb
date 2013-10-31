require 'spec_helper'

module Skylight
  describe Normalizers do

    let(:config) do
      # the second path represents rails root
      Config.new normalizers: { render: { view_paths: %w(/path/to/views /path/to) }}
    end

    describe "render_collection.action_view" do

      it "normalizes the notification name" do
        name, title, desc, payload = normalize(identifier: "foo/bar", count: 10)
        name.should == "view.render.collection"
        title.should == "foo/bar"
        desc.should == nil
        payload.should == { count: 10 }
      end

      it "normalizes the title to a path relative to view paths" do
        name, title, desc, payload = normalize(config, { identifier: "/path/to/views/foo/bar", count: 10 })
        name.should == "view.render.collection"
        title.should == "foo/bar"
        desc.should == nil
        payload.should == { count: 10 }
      end

      it "normalizes the title to a path relative to rails root" do
        name, title, desc, payload = normalize(config, { identifier: "/path/to/other/path", count: 10 })
        name.should == "view.render.collection"
        title.should == "other/path"
        desc.should == nil
        payload.should == { count: 10 }
      end

      it "prints Absolute Path if it's outside the root" do
        name, title, desc, payload = normalize(config, { identifier: "/other/path/to/stuff", count: 10 })
        name.should == "view.render.collection"
        title.should == "Absolute Path"
        desc.should == nil
        payload.should == { count: 10, skylight_error: ["absolute_path", "/other/path/to/stuff"] }
      end
    end

    describe "render_template.action_view" do

      it "normalizes the notification name" do
        name, title, desc, payload = normalize(config, identifier: "foo/bar")
        name.should == "view.render.template"
        title.should == "foo/bar"
        desc.should == nil
        payload.should == { partial: 0 }
      end

      it "normalizes the title to a relative path" do
        name, title, desc, payload = normalize(config, { identifier: "/path/to/views/foo/bar" })
        name.should == "view.render.template"
        title.should == "foo/bar"
        desc.should == nil 
        payload.should == { partial: 0 }
      end

      it "normalizes the title to a path relative to rails root" do
        name, title, desc, payload = normalize(config, { identifier: "/path/to/other/path" })
        name.should == "view.render.template"
        title.should == "other/path"
        desc.should == nil
        payload.should == { partial: 0 }
      end

      it "prints Absolute Path if it's outside the root" do
        name, title, desc, payload = normalize(config, { identifier: "/other/path/to/stuff" })
        name.should == "view.render.template"
        title.should == "Absolute Path"
        desc.should == nil
        payload.should == { partial: 0, skylight_error: ["absolute_path", "/other/path/to/stuff"] }
      end
    end

    describe "render_partial.action_view" do

      it "normalizes the notification name" do
        name, title, desc, payload = normalize(config, identifier: "foo/bar")
        name.should == "view.render.template"
        title.should == "foo/bar"
        desc.should == nil
        payload.should == { partial: 1 }
      end

      it "normalizes the title to a relative path" do
        name, title, desc, payload = normalize(config, { identifier: "/path/to/views/foo/bar" })
        name.should == "view.render.template"
        title.should == "foo/bar"
        desc.should == nil
        payload.should == { partial: 1 }
      end

      it "normalizes the title to a path relative to rails root" do
        name, title, desc, payload = normalize(config, { identifier: "/path/to/other/path" })
        name.should == "view.render.template"
        title.should == "other/path"
        desc.should == nil
        payload.should == { partial: 1 }
      end

      it "prints Absolute Path if it's outside the root" do
        name, title, desc, payload = normalize(config, { identifier: "/other/path/to/stuff" })
        name.should == "view.render.template"
        title.should == "Absolute Path"
        desc.should == nil
        payload.should == { partial: 1, skylight_error: ["absolute_path", "/other/path/to/stuff"] }
      end
    end
  end
end
