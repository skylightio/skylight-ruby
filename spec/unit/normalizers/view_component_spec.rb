require "spec_helper"

module Skylight
  describe "Normalizers", :agent do
    describe "render.view_component" do
      # FIXME: prefer to generate payloads via the library under test.
      it "normalizes with component class name as title" do
        payload = { name: "MyComponent", identifier: "/app/components/my_component.rb" }
        cat, title, desc, meta = normalize(payload)
        expect(cat).to eq("view.render.component")
        expect(title).to eq("MyComponent")
        expect(desc).to be_nil
        expect(meta[:source_file]).to eq("/app/components/my_component.rb")
      end

      it "normalizes namespaced component names" do
        payload = { name: "Admin::HeaderComponent", identifier: "/app/components/admin/header_component.rb" }
        cat, title, desc, meta = normalize(payload)
        expect(cat).to eq("view.render.component")
        expect(title).to eq("Admin::HeaderComponent")
        expect(desc).to be_nil
        expect(meta[:source_file]).to eq("/app/components/admin/header_component.rb")
      end

      it "handles nil name" do
        payload = { name: nil, identifier: "/app/components/my_component.rb" }
        cat, title, desc = normalize(payload)
        expect(cat).to eq("view.render.component")
        expect(title).to be_nil
        expect(desc).to be_nil
      end

      it "handles missing identifier" do
        payload = { name: "MyComponent" }
        cat, title, desc, meta = normalize(payload)
        expect(cat).to eq("view.render.component")
        expect(title).to eq("MyComponent")
        expect(desc).to be_nil
        expect(meta).not_to have_key(:source_file)
      end
    end
  end
end
