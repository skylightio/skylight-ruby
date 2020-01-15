module Skylight
  module Probes
    module Faraday
      module Instrumentation
        def builder
          unless defined?(@__sk__setup)
            @__sk__setup = true
            @builder.insert 0, ::Faraday::Request::Instrumentation
          end
          @builder
        end
      end

      class Probe
        def install
          ::Faraday::Connection.prepend(Instrumentation)
        end
      end
    end

    register(:faraday, "Faraday", "faraday", Faraday::Probe.new)
  end
end
