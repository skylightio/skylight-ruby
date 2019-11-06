module Skylight
  module Probes
    module Mongoid
      class Probe
        def install
          require "mongoid/version"
          version = Gem::Version.new(::Mongoid::VERSION)

          if version < Gem::Version.new("5.0")
            Skylight::Probes.probe(:moped)
          else
            Skylight::Probes.probe(:mongo)
          end
        end
      end
    end

    register(:mongoid, "Mongoid", "mongoid", Mongoid::Probe.new)
  end
end
