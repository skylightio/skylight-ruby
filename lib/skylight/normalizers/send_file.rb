module Skylight
  module Normalizers

    # Temporary hacks
    begin
      require "action_dispatch/http/mime_type"
      require "action_dispatch/http/mime_types"
      require "rack/utils"

      class SendFile < Normalizer
        register "send_file.action_controller"

        def normalize(trace, name, payload)
          path = payload[:path]

          annotations = {
            path:        path,
            filename:    payload[:filename],
            type:        normalize_type(payload),
            disposition: normalize_disposition(payload),
            status:      normalize_status(payload) }

          title = "send file"

          # depending on normalization, we probably want this to eventually
          # include the full path, but we need to make sure we have a good
          # deduping strategy first.
          desc = nil

          [ "app.controller.send_file", title, desc, annotations ]
        end

      private

        def normalize_type(payload)
          type = payload[:type] || "application/octet-stream"
          type = Mime[type].to_s if type.is_a?(Symbol)
          type
        end

        def normalize_status(payload)
          status = payload[:status] || 200
          Rack::Utils.status_code(status)
        end

        def normalize_disposition(payload)
          payload[:disposition] || "attachment"
        end
      end

    rescue LoadError
    end

  end
end
