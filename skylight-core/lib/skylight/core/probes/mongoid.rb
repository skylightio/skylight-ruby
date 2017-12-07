module Skylight::Core
  module Probes
    module Mongoid
      class Probe

        def install
          require 'mongoid/version'
          version = Gem::Version.new(::Mongoid::VERSION)

          if version < Gem::Version.new("5.0")
            require 'skylight/core/probes/moped'
          else
            require 'skylight/core/probes/mongo'
          end
        end
      end
    end

    register("Mongoid", "mongoid", Mongoid::Probe.new)
  end
end