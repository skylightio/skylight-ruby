require 'spec_helper'

describe 'Tilt integration', :tilt_probe, :agent do
  it "instruments Tilt templates that have a sky_virtual_path" do
    tilt = ::Tilt::ERBTemplate.new(nil, 1, sky_virtual_path: "template") { "hello" }

    expected = {
      category: "view.render.template",
      title: "template"
    }

    Skylight.should_receive(:instrument).with(expected).and_call_original

    tilt.render.should == "hello"
  end

  it "instruments Tilt templates without a sky_virtual_path, using `Unknown template name`" do
    tilt = ::Tilt::ERBTemplate.new { "hello" }

    expected = {
      category: "view.render.template",
      title: "Unknown template name"
    }

    Skylight.should_receive(:instrument).with(expected).and_call_original

    tilt.render.should == "hello"
  end
end
