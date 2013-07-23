module Skylight
  module Messages
    class Base
      module ClassMethods
        attr_accessor :message_id
      end

      def self.inherited(klass)
        klass.class_eval do
          include Beefcake::Message
          extend  ClassMethods
        end

        klass.message_id = (@count ||= 0)
        Messages.set(klass.message_id, klass)
        @count += 1
      end

      def message_id
        self.class.message_id
      end
    end
  end
end
