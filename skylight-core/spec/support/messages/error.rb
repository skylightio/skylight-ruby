module SpecHelper
  module Messages
    class Error
      include Beefcake::Message

      required :type,        :string, 1
      required :description, :string, 2
      optional :details,     :string, 3
    end
  end
end
