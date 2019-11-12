require "delegate"
require "spec_helper"

if defined?(ActionPack)
  describe "ActionView integration", :action_view_probe, :agent do
    class Context < ActionView::Base
      module CompiledTemplates
      end

      include CompiledTemplates

      def find_all(name, *_args)
        handler = ::ActionView::Template.handler_for_extension("erb")
        case name
        when "our-layout"
          [::ActionView::Template.new("<<%= yield %>>", "test layout", handler, {})]
        when "our-template"
          [::ActionView::Template.new("Hello World", "test template", handler, {})]
        else
          raise ArgumentError, "no template"
        end
      end

      def compiled_method_container
        CompiledTemplates
      end
    end

    let(:context) do
      Context.new
    end

    let(:lookup_context) do
      ::ActionView::LookupContext.new(context)
    end

    let(:renderer_inner) do
      ::ActionView::TemplateRenderer.new(lookup_context)
    end

    let(:renderer) { Renderer.new(renderer_inner) }

    class Renderer < SimpleDelegator
      def render(*args, &block)
        __getobj__.render(*args, &block).tap do |result|
          return result.body if ActionView::VERSION::MAJOR >= 6
        end
      end
    end

    let(:events) { [] }

    around do |example|
      callback = lambda do |*args|
        events << args
      end

      ::ActiveSupport::Notifications.subscribed(callback, "render_template.action_view") do
        example.run
      end
    end

    def render_plain(renderer, context, opts)
      opts[:text] = opts.delete(:plain) if ActionView::VERSION::MAJOR < 5
      renderer.render(context, opts)
    end

    it "instruments layouts when :text is used with a layout" do
      expect(render_plain(renderer, context, plain: "Hello World", layout: "our-layout")).to eq("<Hello World>")

      expect(events.map { |e| [e[0], e[4][:identifier]] }).to eq([
        ["render_template.action_view", "text template"],
        ["render_template.action_view", "test layout"]
      ])
    end

    it "does not instrument layouts when :text is used without a layout" do
      expect(render_plain(renderer, context, plain: "Hello World")).to eq("Hello World")

      expect(events.map { |e| [e[0], e[4][:identifier]] }).to eq([
        ["render_template.action_view", "text template"]
      ])
    end

    it "instruments layouts when :inline is used with a layout" do
      expect(renderer.render(context, inline: "Hello World", layout: "our-layout")).to eq("<Hello World>")

      expect(events.map { |e| [e[0], e[4][:identifier]] }).to eq([
        ["render_template.action_view", "inline template"],
        ["render_template.action_view", "test layout"]
      ])
    end

    it "does not instrument layouts when :inline is used without a layout" do
      expect(renderer.render(context, inline: "Hello World")).to eq("Hello World")

      expect(events.map { |e| [e[0], e[4][:identifier]] }).to eq([
        ["render_template.action_view", "inline template"]
      ])
    end

    it "instruments layouts when :template is used with a layout" do
      expect(renderer.render(context, template: "our-template", layout: "our-layout")).to eq("<Hello World>")

      expect(events.map { |e| [e[0], e[4][:identifier]] }).to eq([
        ["render_template.action_view", "test template"],
        ["render_template.action_view", "test layout"]
      ])
    end

    it "does not instrument layouts when :template is used without a layout" do
      expect(renderer.render(context, template: "our-template")).to eq("Hello World")

      expect(events.map { |e| [e[0], e[4][:identifier]] }).to eq([
        ["render_template.action_view", "test template"]
      ])
    end
  end
end
