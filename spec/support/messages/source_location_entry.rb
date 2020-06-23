module SpecHelper
  module Messages
    class SourceLocationEntry
      include Beefcake::Message

      required :index, :uint64, 1
      required :name,  :string, 2
    end
  end
end
