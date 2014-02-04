module Skylight
  module Messages
    class Error
      def self.deserialize(buf)
        decode(buf)
      end

      def self.build(group, description, details = nil)
        Skylight::Error.native_new(group, description).tap do |error|
          error.native_set_details(details) if details
        end
      end
    end
  end
end
