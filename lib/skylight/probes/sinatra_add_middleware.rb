module Skylight
  module Probes
    module Sinatra
      class AddMiddlewareProbe
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

    register(:sinatra_add_middleware, "Sinatra::Base", "sinatra/base", Sinatra::AddMiddlewareProbe.new)
  end
end
