require 'spec_helper'
require 'skylight/instrumenter'

describe 'Sinatra integration', :sinatra_probe, :agent do
  include Rack::Test::Methods

  before do
    Skylight::Instrumenter.mock! do |trace|
      trace.endpoint.should == @expected_endpoint
    end
  end

  after do
    Skylight::Instrumenter.stop!
  end

  class SinatraTest < ::Sinatra::Base
    disable :show_exceptions

    template :hello do
      "Hello from named template"
    end

    get "/named-template" do
      erb :hello
    end

    get "/inline-template" do
      erb "Hello from inline template"
    end
  end

  def app
    SinatraTest
  end

  it "creates a Trace for a Sinatra app" do
    @expected_endpoint = "GET /named-template"

    Skylight.should_receive(:trace).with("Rack", "app.rack.request").and_call_original

    get "/named-template"
    last_response.body.should == "Hello from named template"
  end

  it "instruments named templates" do
    @expected_endpoint = "GET /named-template"

    Skylight.should_receive(:instrument).with(
      category: "view.render.template",
      title: "hello"
    ).and_call_original

    get "/named-template"
  end

  it "instruments inline templates" do
    @expected_endpoint = "GET /inline-template"

    Skylight.should_receive(:instrument).with(
      category: "view.render.template",
      title: "Inline template (erb)"
    ).and_call_original

    get "/inline-template"
  end
end
