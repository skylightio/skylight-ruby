require "skylight/formatters/http"

module Skylight
  module Probes
    module HTTPClient
      module Instrumentation
        # HTTPClient has request methods on the class object itself,
        # but they internally instantiate a client and perform the method
        # on that, so this instance method override will cover both
        # `HTTPClient.get(...)` and `HTTPClient.new.get(...)`

        def do_request(method, uri, *)
          return super if Probes::HTTPClient::Probe.disabled?

          opts = Formatters::HTTP.build_opts(method, uri.scheme, uri.host, uri.port, uri.path, uri.query)

          Skylight.instrument(opts) { super }
        end
      end

      class Probe
        DISABLED_KEY = :__skylight_httpclient_disabled

        def self.disable
          old_value = Thread.current[DISABLED_KEY]
          Thread.current[DISABLED_KEY] = true
          yield
        ensure
          Thread.current[DISABLED_KEY] = old_value
        end

        def self.disabled?
          !!Thread.current[DISABLED_KEY]
        end

        def install
          ::HTTPClient.prepend(Instrumentation)
        end
      end
    end

    register(:httpclient, "HTTPClient", "httpclient", HTTPClient::Probe.new)
  end
end
