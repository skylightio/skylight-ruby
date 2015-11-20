module Skylight
  module Probes
    module Mongoid
      class Probe

        def install
          require 'mongoid/version'
          version = Gem::Version.new(::Mongoid::VERSION)

          if version < Gem::Version.new("5.0")
            require 'skylight/probes/moped'
          else
            require 'skylight/probes/mongo'
          end
        end
      end
    end

    register("Mongoid", "mongoid", Mongoid::Probe.new)
  end
end