module Skylight::Core
  module Normalizers
    module ActionController
      # Temporary hacks
      begin
        require "action_dispatch/http/mime_type"
        require "action_dispatch/http/mime_types"
        require "rack/utils"

        class SendFile < Normalizer
          register "send_file.action_controller"

          CAT = "app.controller.send_file".freeze
          TITLE = "send file".freeze

          def normalize(_trace, _name, _payload)
            title = TITLE

            # depending on normalization, we probably want this to eventually
            # include the full path, but we need to make sure we have a good
            # deduping strategy first.
            desc = nil

            [CAT, title, desc]
          end

          private

            OCTET_STREAM = "application/octet-stream".freeze
            ATTACHMENT = "attachment".freeze

            def initialize(*)
              super

              @mimes = Mime::SET.each_with_object({}) do |mime, hash|
                hash[mime.symbol] = mime.to_s.dup.freeze
                hash
              end
            end
        end
      rescue LoadError
      end
    end
  end
end
