module Skylight
  module Probes
    module Faraday
      module Instrumentation
        def initialize(*)
          super
          @builder.insert 0, ::Faraday::Request::Instrumentation
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
