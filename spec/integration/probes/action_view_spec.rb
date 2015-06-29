require 'spec_helper'

if defined?(ActionPack) && [ActionPack::VERSION::MAJOR, ActionPack::VERSION::MINOR] != [3, 0]
  describe 'ActionView 3.1+ integration', :action_view_probe, :agent do
    class Context
      include ::ActionView::Context

      def initialize
        _prepare_context
      end

      def find_all(name, *args)
        handler = ::ActionView::Template.handler_for_extension("erb")
        case name
        when "our-layout"
          [::ActionView::Template.new("<<%= yield %>>", "test layout", handler, locals: {})]
        when "our-template"
          [::ActionView::Template.new("Hello World", "test template", handler, locals: {})]
        else
          raise ArgumentError, "no template"
        end
      end
    end

    let(:context) do
      Context.new
    end

    let(:lookup_context) do
      ::ActionView::LookupContext.new(context)
    end

    let(:renderer) do
      ::ActionView::TemplateRenderer.new(lookup_context)
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

    it "instruments layouts when :text is used with a layout" do
      renderer.render(context, text: "Hello World", layout: "our-layout").should == "<Hello World>"

      events.map { |e| [e[0], e[4][:identifier]] }.should == [
        ["render_template.action_view", "text template"],
        ["render_template.action_view", "test layout"]
      ]
    end

    it "does not instrument layouts when :text is used without a layout" do
      renderer.render(context, text: "Hello World").should == "Hello World"

      events.map { |e| [e[0], e[4][:identifier]] }.should == [
        ["render_template.action_view", "text template"],
      ]
    end

    it "instruments layouts when :inline is used with a layout" do
      renderer.render(context, inline: "Hello World", layout: "our-layout").should == "<Hello World>"

      events.map { |e| [e[0], e[4][:identifier]] }.should == [
        ["render_template.action_view", "inline template"],
        ["render_template.action_view", "test layout"]
      ]
    end

    it "does not instrument layouts when :inline is used without a layout" do
      renderer.render(context, inline: "Hello World").should == "Hello World"

      events.map { |e| [e[0], e[4][:identifier]] }.should == [
        ["render_template.action_view", "inline template"],
      ]
    end

    it "instruments layouts when :template is used with a layout" do
      renderer.render(context, template: "our-template", layout: "our-layout").should == "<Hello World>"

      events.map { |e| [e[0], e[4][:identifier]] }.should == [
        ["render_template.action_view", "test template"],
        ["render_template.action_view", "test layout"]
      ]
    end

    it "does not instrument layouts when :template is used without a layout" do
      renderer.render(context, template: "our-template").should == "Hello World"

      events.map { |e| [e[0], e[4][:identifier]] }.should == [
        ["render_template.action_view", "test template"],
      ]
    end
  end
end
