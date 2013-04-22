module Skylight
  module Normalize

    # Temporary hacks
    begin
      require "action_dispatch/http/mime_type"
      require "action_dispatch/http/mime_types"
      require "rack/utils"

      class SendFile < Normalizer
        register "send_file.action_controller"

        def normalize
          path = @payload[:path]

          annotations = {
            path: path,
            filename: @payload[:filename],
            type: normalize_type,
            disposition: normalize_disposition,
            status: normalize_status
          }

          # These will eventually be different
          title = desc = "send file: #{path}"

          [ "app.controller.send_file", title, desc, annotations ]
        end

      private
        def normalize_type
          type = @payload[:type] || "application/octet-stream"
          type = Mime[type].to_s if type.is_a?(Symbol)
          type
        end

        def normalize_status
          status = @payload[:status] || 200
          Rack::Utils.status_code(status)
        end

        def normalize_disposition
          @payload[:disposition] || "attachment"
        end
      end

    rescue LoadError
    end

  end
end
