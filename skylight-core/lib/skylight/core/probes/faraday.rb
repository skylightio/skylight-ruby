module Skylight::Core
  module Probes
    module Faraday
      class Probe
        def install
          ::Faraday::Connection.class_eval do
            alias_method :initialize_without_sk, :initialize

            def initialize(*args, &block)
              initialize_without_sk(*args, &block)

              @builder.insert 0, ::Faraday::Request::Instrumentation
            end
          end
        end
      end
    end

    register(:faraday, "Faraday", "faraday", Faraday::Probe.new)
  end
end
