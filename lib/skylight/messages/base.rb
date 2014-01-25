module Skylight
  module Messages
    class Base
      def self.inherited(klass)
        klass.class_eval do
          include Beefcake::Message
        end
      end
    end
  end
end
