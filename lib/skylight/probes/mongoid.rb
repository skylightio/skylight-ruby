module Skylight
  module Probes
    module Mongoid
      class Probe

        def install
          require 'mongoid/version'
          version = Gem::Version.new(::Mongoid::VERSION)

          if version < Gem::Version.new("5.0")
            Skylight.probe(:moped)
          else
            Skylight.probe(:mongo)
          end
        end
      end
    end

    register(:mongoid, "Mongoid", "mongoid", Mongoid::Probe.new)
  end
end