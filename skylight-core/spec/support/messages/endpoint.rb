module SpecHelper
  module Messages
    class Endpoint
      include Beefcake::Message

      required :name,   :string, 1
      required :count,  :uint64, 2
      repeated :traces, Trace,   3

    end
  end
end
