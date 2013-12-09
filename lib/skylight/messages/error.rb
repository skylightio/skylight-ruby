require 'skylight/messages/base'

module Skylight
  module Messages
    class Error < Base
      required :type,        :string, 1
      required :description, :string, 2
      optional :details,     :string, 3
    end
  end
end
