module SpecHelper
  module Messages
    class Trace
      include Beefcake::Message

      required :uuid,     :string, 1
      optional :endpoint, :string, 2
      repeated :spans,    Span,    3
    end
  end
end
