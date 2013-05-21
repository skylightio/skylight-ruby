module Skylight
  module Messages
    class Endpoint
      include Beefcake::Message

      required :name,   String, 1
      repeated :traces, Trace,  2

    end
  end
end
