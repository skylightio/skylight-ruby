module Skylight::Core
  module Normalizers
    module ActiveRecord
      class Instantiation < Normalizer
        register "instantiation.active_record"

        CAT = "db.active_record.instantiation".freeze

        def normalize(_trace, _name, payload)
          # Payload also includes `:record_count` but this will be variable
          [CAT, "#{payload[:class_name]} Instantiation", nil]
        end
      end
    end
  end
end
