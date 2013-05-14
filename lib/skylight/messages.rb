module Skylight
  module Messages
    def self.get(id)
      (@id_map ||= {})[id]
    end

    def self.set(id, klass)
      (@id_map ||= {})[id] = klass
    end

    require 'skylight/messages/pid'
    require 'skylight/messages/trace'
  end
end
