module Skylight
  module Probes
    module Elasticsearch
      class Probe
        def install
          ::Elasticsearch::Transport::Transport::Base.class_eval do
            alias perform_request_without_sk perform_request
            def perform_request(method, path, *args, &block)
              ActiveSupport::Notifications.instrument "request.elasticsearch",
                                                      name:   'Request',
                                                      method: method,
                                                      path:   path do

                # Prevent HTTP-related probes from firing
                disable_skylight_probe(:NetHTTP) do
                  disable_skylight_probe(:HTTPClient) do
                    perform_request_without_sk(method, path, *args, &block)
                  end
                end
              end
            end

            def disable_skylight_probe(class_name, &block)
              klass = Skylight::Probes.const_get(class_name).const_get(:Probe) rescue nil
              klass ? klass.disable(&block) : block.call
            end
          end
        end
      end
    end

    register("Elasticsearch", "elasticsearch", Elasticsearch::Probe.new)
  end
end
