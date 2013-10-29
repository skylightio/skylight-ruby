require 'skylight/messages/base'

module Skylight
  module Messages
    class Error < Base
      required :reason, :string, 1
      required :body,   :string, 2
    end
  end
end
