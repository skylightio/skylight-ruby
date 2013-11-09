module Skylight
  module Normalizers

    # Temporary hacks
    begin
      require "action_dispatch/http/mime_type"
      require "action_dispatch/http/mime_types"
      require "rack/utils"

      class SendFile < Normalizer
        register "send_file.action_controller"

        CAT = "app.controller.send_file".freeze
        TITLE = "send file".freeze

        def normalize(trace, name, payload)
          path = payload[:path]

          annotations = {
            path:        path,
            filename:    payload[:filename],
            type:        normalize_type(payload),
            disposition: normalize_disposition(payload),
            status:      normalize_status(payload) }

          title = TITLE

          # depending on normalization, we probably want this to eventually
          # include the full path, but we need to make sure we have a good
          # deduping strategy first.
          desc = nil

          [ CAT, title, desc, annotations ]
        end

      private

        OCTET_STREAM = "application/octet-stream".freeze
        ATTACHMENT = "attachment".freeze

        def initialize(*)
          super

          @mimes = Mime::SET.reduce({}) do |hash, mime|
            hash[mime.symbol] = mime.to_s.dup.freeze
            hash
          end
        end

        def normalize_type(payload)
          type = payload[:type] || OCTET_STREAM
          type = @mimes[type] if type.is_a?(Symbol)
          type
        end

        def mime_for(type)
          @mimes[type] ||= Mime[type].to_s.freeze
        end

        def normalize_status(payload)
          status = payload[:status] || 200
          Rack::Utils.status_code(status)
        end

        def normalize_disposition(payload)
          payload[:disposition] || ATTACHMENT
        end
      end

    rescue LoadError
    end

  end
end
