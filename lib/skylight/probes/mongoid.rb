module Skylight
  module Probes
    module Mongoid
      class Probe
        def install
          Skylight::Probes.probe(:mongo)
        end
      end
    end

    register(:mongoid, "Mongoid", "mongoid", Mongoid::Probe.new)
  end
end
