require 'skylight/messages/base'

module Skylight
  module Messages
    class Hello < Base

      required :version, :string, 1

    end
  end
end
