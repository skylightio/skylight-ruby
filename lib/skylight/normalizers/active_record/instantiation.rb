module Skylight
  module Normalizers
    module ActiveRecord
      class Instantiation < Normalizer
        register "instantiation.active_record"

        CAT = "db.active_record.instantiation".freeze

        def normalize(trace, name, payload)
          # Payload also includes `:record_count` but this will be variable
          [ CAT, payload[:class_name], nil]
        end

      end
    end
  end
end
