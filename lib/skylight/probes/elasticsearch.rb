module Skylight
  module Probes
    module Elasticsearch
      class Probe
        def install
          # Prepending doesn't work here since this a module that's already been included
          ::Elasticsearch::Transport::Transport::Base.class_eval do
            alias_method :perform_request_without_sk, :perform_request
            def perform_request(method, path, *args, &block)
              ActiveSupport::Notifications.instrument(
                "request.elasticsearch",
                name:   "Request",
                method: method,
                path:   path
              ) do
                # Prevent HTTP-related probes from firing
                Skylight::Normalizers::Faraday::Request.disable do
                  disable_skylight_probe(:NetHTTP) do
                    disable_skylight_probe(:HTTPClient) do
                      perform_request_without_sk(method, path, *args, &block)
                    end
                  end
                end
              end
            end

            def disable_skylight_probe(class_name)
              klass = ::ActiveSupport::Inflector.safe_constantize("Skylight::Probes::#{class_name}::Probe")
              (klass ? klass.disable { yield } : yield).tap { puts "re-enabling: #{klass}" }
            end
          end
        end
      end
    end

    register(:elasticsearch, "Elasticsearch", "elasticsearch", Elasticsearch::Probe.new)
  end
end
