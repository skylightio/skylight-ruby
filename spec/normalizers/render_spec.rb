require 'spec_helper'

module Skylight
  describe Normalizers do

    let(:config) do
      # the second path represents rails root
      Config.new normalizers: { render: { view_paths: %w(/path/to/views /path/to) }}
    end

    shared_examples_for "low allocator" do
      it "allocates 1 array, 1 string, 1 hash when normalizing the notification name", allocations: true do
        payload = { identifier: "foo/bar", count: 10 }

        # prime
        normalize(payload)

        lambda { normalize(payload) }.should allocate(array: 1, hash: 1)
      end

      it "allocates 1 string, 1 array and 1 hash when normalizing the title to a path relative to view paths", allocations: true do
        payload = { identifier: "/path/to/views/foo/bar", count: 10 }

        # prime
        normalize(payload)

        lambda { normalize(payload) }.should allocate(string: 1, array: 1, hash: 1)
      end

      it "allocates 1 string, 1 array and 1 hash when normalizing the title to a path relative to the Rails root", allocations: true do
        payload = { identifier: "/path/to/other/path", count: 10 }

        # prime
        normalize(payload)

        lambda { normalize(payload) }.should allocate(string: 1, array: 1, hash: 1)
      end
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
      it_should_behave_like "low allocator"
      it_should_behave_like "template normalizer"

      def group_payload
        { count: 10 }
      end

      def group_name
        "view.render.collection"
      end
    end

    describe "render_template.action_view" do
      it_should_behave_like "low allocator"
      it_should_behave_like "template normalizer"

      def group_payload
        { partial: 0 }
      end

      def group_name
        "view.render.template"
      end
    end

    describe "render_partial.action_view" do
      it_should_behave_like "low allocator"
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
