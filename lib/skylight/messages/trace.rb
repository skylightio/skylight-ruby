require 'skylight/messages/base'

module Skylight
  module Messages
    class Trace < Base

      required :uuid, :string, 1

    end
  end
end
