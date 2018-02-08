require 'skylight/core/formatters/http'

module Skylight::Core
  module Probes
    module NetHTTP
      # Probe for instrumenting Net::HTTP requests. Works by monkeypatching the default Net::HTTP#request method.
      class Probe
        DISABLED_KEY = :__skylight_net_http_disabled

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
          Net::HTTP.class_eval do
            alias request_without_sk request

            def request(req, body = nil, &block)
              if !started? || Probes::NetHTTP::Probe.disabled?
                return request_without_sk(req, body, &block)
              end

              method = req.method

              # req['host'] also includes special handling for default ports
              host, port = req['host'] ? req['host'].split(':') : nil

              # If we're connected with a persistent socket
              host ||= self.address
              port ||= self.port

              path   = req.path
              scheme = use_ssl? ? "https" : "http"

              # Contained in the path
              query  = nil

              opts = Formatters::HTTP.build_opts(method, scheme, host, port, path, query)

              Skylight::Core::Fanout.instrument(opts) do |spans|
                spans.each do |(instrumentable, span)|
                  # TODO: Should we make something more generic?
                  if (header = instrumentable.correlation_header)
                    req[header] = instrumentable.span_correlation_header(span)
                  end
                end
                request_without_sk(req, body, &block)
              end
            end
          end
        end
      end
    end

    register("Net::HTTP", "net/http", NetHTTP::Probe.new)
  end
end
