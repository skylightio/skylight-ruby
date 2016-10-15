require 'skylight/formatters/http'

module Skylight
  module Probes
    module HTTPClient
      class Probe
        DISABLED_KEY = :__skylight_httpclient_disabled

        def self.disable
          Thread.current[DISABLED_KEY] = true
          yield
        ensure
          Thread.current[DISABLED_KEY] = false
        end

        def self.disabled?
          !!Thread.current[DISABLED_KEY]
        end

        def install
          ::HTTPClient.class_eval do
            # HTTPClient has request methods on the class object itself,
            # but the internally instantiate a client and perform the method
            # on that, so this instance method override will cover both
            # `HTTPClient.get(...)` and `HTTPClient.new.get(...)`

            alias do_request_without_sk do_request
            def do_request(method, uri, query, body, header, &block)
              if Skylight::Probes::HTTPClient::Probe.disabled?
                return do_request_without_sk(method, uri, query, body, header, &block)
              end

              opts = Formatters::HTTP.build_opts(method, uri.scheme, uri.host, uri.port, uri.path, uri.query)

              Skylight.instrument(opts) do
                do_request_without_sk(method, uri, query, body, header, &block)
              end
            end
          end
        end
      end # class Probe
    end # module Probes::HTTPClient

    register("HTTPClient", "httpclient", HTTPClient::Probe.new)
  end
end
