require "spec_helper"

module Skylight
  describe "Normalizers", :agent do
    let(:project_root) { "/app/src" }
    let(:config) do
      # the second path represents rails root
      Config.new normalizers: { render: { view_paths: %W[
        #{project_root}/app/views
        #{project_root}
      ] } }
    end

    shared_examples_for "template normalizer" do
      it "normalizes the notification name" do
        complete_payload = { identifier: "foo/bar" }
        name, title, desc = normalize(complete_payload)
        expect(name).to eq(group_name)
        expect(title).to eq("foo/bar")
        expect(desc).to eq(nil)
      end

      it "normalizes the title to a path relative to view paths" do
        complete_payload = {
          identifier: "#{project_root}/app/views/foo/bar",
          count:      10
        }
        name, title, desc = normalize(complete_payload)
        expect(name).to eq(group_name)
        expect(title).to eq("foo/bar")
        expect(desc).to eq(nil)
      end

      it "normalizes the title to a path relative to rails root" do
        complete_payload = { identifier: "#{project_root}/other/path" }
        name, title, desc = normalize(complete_payload)
        expect(name).to eq(group_name)
        expect(title).to eq("other/path")
        expect(desc).to eq(nil)
      end

      it "normalizes the title to a path relative to Gem.path (vendor)" do
        path = "#{project_root}/vendor/bundle/ruby/2.5.0"
        allow(Gem).to receive(:path).and_return([path])

        complete_payload = {
          identifier: "#{path}/bundler/gems/blorgh-gem-19a101f550c9/app/views/monster/blorgh/posts/index.html.erb"
        }
        name, title, desc = normalize(complete_payload)
        expect(name).to eq(group_name)
        expect(title).to eq("blorgh-gem: monster/blorgh/posts/index.html.erb")
        expect(desc).to eq(nil)
      end

      it "normalizes the title to a path relative to Gem.path" do
        path = "/some/path/to/ruby/2.5.0"
        allow(Gem).to receive(:path).and_return([path])

        complete_payload = {
          identifier: "#{path}/gems/blorgh-gem-1.0.0/app/views/monster/blorgh/posts/index.html.erb"
        }
        name, title, desc = normalize(complete_payload)
        expect(name).to eq(group_name)
        expect(title).to eq("blorgh-gem: monster/blorgh/posts/index.html.erb")
        expect(desc).to eq(nil)
      end

      it "normalizes the title to a path relative to Gem.path (custom view location in Gem)" do
        path = "/some/path/to/ruby/2.5.0"
        allow(Gem).to receive(:path).and_return([path])

        complete_payload = {
          identifier: "#{path}/gems/blorgh-gem-1.0.0/path/to/views/monster/blorgh/posts/index.html.erb"
        }
        name, title, desc = normalize(complete_payload)
        expect(name).to eq(group_name)
        expect(title).to eq("blorgh-gem: path/to/views/monster/blorgh/posts/index.html.erb")
        expect(desc).to eq(nil)
      end

      it "prints Absolute Path if it's outside the root" do
        complete_payload = {
          identifier: "/other#{project_root}/stuff"
        }
        name, title, desc = normalize(complete_payload)
        expect(name).to eq(group_name)
        expect(title).to eq("Absolute Path")
        expect(desc).to eq(nil)
      end
    end

    describe "render_collection.action_view" do
      it_should_behave_like "template normalizer"

      def group_name
        "view.render.collection"
      end
    end

    describe "render_template.action_view" do
      it_should_behave_like "template normalizer"

      def group_name
        "view.render.template"
      end
    end

    describe "render_partial.action_view" do
      it_should_behave_like "template normalizer"

      def group_name
        "view.render.template"
      end
    end

    describe "render_layout.action_view" do
      it_should_behave_like "template normalizer"

      def group_name
        "view.render.layout"
      end
    end
  end
end
