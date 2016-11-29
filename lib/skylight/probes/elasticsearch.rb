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

                # Prevent Net::HTTP instrumenter from firing
                Skylight::Probes::NetHTTP::Probe.disable do
                  Skylight::Probes::HTTPClient::Probe.disable do
                    perform_request_without_sk(method, path, *args, &block)
                  end
                end
              end
            end
          end
        end
      end
    end

    register("Elasticsearch", "elasticsearch", Elasticsearch::Probe.new)
  end
end
