require 'skylight/messages/base'

module Skylight
  module Messages
    class Error < Base
      def self.deserialize(buf)
        decode(buf)
      end

      def self.build(group, description, details = nil)
        Skylight::Error.native_new(group, description).tap do |error|
          error.native_set_details(details) if details
        end
      end

      def serialize
        encode.to_s
      end

      required :type,        :string, 1
      required :description, :string, 2
      optional :details,     :string, 3
    end
  end
end
