require 'spec_helper'

module Skylight
  module Probes
    module Excon
      describe Probe, :excon_probe, :probes do

        it "is registered" do
          reg = Skylight::Probes.installed["Excon"]
          reg.klass_name.should == "Excon"
          reg.require_paths.should == ["excon"]
          reg.probe.should be_a(Skylight::Probes::Excon::Probe)
        end

        it "adds a middleware to Excon" do
          middlewares = ::Excon.defaults[:middlewares]

          middlewares.should include(Skylight::Probes::Excon::Middleware)

          # Verify correct positioning
          idx = middlewares.index(Skylight::Probes::Excon::Middleware)
          middlewares[idx+1].should == ::Excon::Middleware::Instrumentor
        end

      end
    end
  end
end