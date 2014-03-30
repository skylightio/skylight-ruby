require 'spec_helper'

module Skylight
  describe "Normalizers", :agent do

    let(:config) do
      # the second path represents rails root
      Config.new normalizers: { render: { view_paths: %w(/path/to/views /path/to) }}
    end

    shared_examples_for "template normalizer" do
      it "normalizes the notification name" do
        complete_payload = { identifier: "foo/bar" }.merge(group_payload)
        name, title, desc, payload = normalize(complete_payload)
        name.should == group_name
        title.should == "foo/bar"
        desc.should == nil
        payload.should == group_payload
      end

      it "normalizes the title to a path relative to view paths" do
        complete_payload = { identifier: "/path/to/views/foo/bar", count: 10 }.merge(group_payload)
        name, title, desc, payload = normalize(complete_payload)
        name.should == group_name
        title.should == "foo/bar"
        desc.should == nil
        payload.should == group_payload
      end

      it "normalizes the title to a path relative to rails root" do
        complete_payload = { identifier: "/path/to/other/path" }.merge(group_payload)
        name, title, desc, payload = normalize(complete_payload)
        name.should == group_name
        title.should == "other/path"
        desc.should == nil
        payload.should == group_payload
      end

      it "normalizes the title to a path relative to Gem.path" do
        path = "/gem/path"
        Gem.stub(path: [path])

        complete_payload = { identifier: "#{path}/foo-1.0/views/bar.html.erb" }.merge(group_payload)
        name, title, desc, payload = normalize(complete_payload)
        name.should == group_name
        title.should == "$GEM_PATH/foo-1.0/views/bar.html.erb"
        desc.should == nil
        payload.should == group_payload
      end

      it "prints Absolute Path if it's outside the root" do
        complete_payload = { identifier: "/other/path/to/stuff" }.merge(group_payload)
        name, title, desc, payload = normalize(complete_payload)
        name.should == group_name
        title.should == "Absolute Path"
        desc.should == nil
        payload.should == group_payload.merge(skylight_error: ["absolute_path", "/other/path/to/stuff"])
      end
    end

    describe "render_collection.action_view" do
      it_should_behave_like "template normalizer"

      def group_payload
        { count: 10 }
      end

      def group_name
        "view.render.collection"
      end
    end

    describe "render_template.action_view" do
      it_should_behave_like "template normalizer"

      def group_payload
        { partial: 0 }
      end

      def group_name
        "view.render.template"
      end
    end

    describe "render_partial.action_view" do
      it_should_behave_like "template normalizer"

      def group_payload
        { partial: 1 }
      end

      def group_name
        "view.render.template"
      end
    end
  end
end
