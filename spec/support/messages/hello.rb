module SpecHelper
  module Messages
    class Hello
      include Beefcake::Message

      required :version, :string, 1
      optional :config,  :uint32, 2
      repeated :cmd,     :string, 3
    end
  end
end
