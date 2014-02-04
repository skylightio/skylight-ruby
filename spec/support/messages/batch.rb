module SpecHelper
  module Messages
    class Batch
      include Beefcake::Message

      required :timestamp, :uint32,  1
      repeated :endpoints, Endpoint, 2
      optional :hostname,  :string,  3

    end
  end
end
