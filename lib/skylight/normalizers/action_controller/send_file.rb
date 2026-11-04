module Skylight
  module Normalizers
    module ActionController
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
      end
    end
  end
end
