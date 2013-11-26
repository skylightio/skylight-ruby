module Skylight
  module Probes
    module NetHTTP
      class Probe
        def install
          Net::HTTP.class_eval do
            alias request_without_sk request

            def request(req, body = nil, &block)
              unless started?
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

              Skylight.instrument(opts) do
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