module SpecHelper
  module Messages
    class Event
      include Beefcake::Message

      required :category,    :string, 1
      optional :title,       :string, 2
      optional :description, :string, 3

    end
  end
end
