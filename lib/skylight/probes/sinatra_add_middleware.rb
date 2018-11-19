module Skylight
  module Probes
    module Sinatra
      class Probe
        def install
          class << ::Sinatra::Base
            alias_method :build_without_sk, :build

            def build(*args, &block)
              use Skylight::Middleware
              build_without_sk(*args, &block)
            end
          end
        end
      end
    end

    Skylight::Core::Probes.register(:sinatra_add_middleware, "Sinatra::Base", "sinatra/base", Sinatra::Probe.new)
  end
end
