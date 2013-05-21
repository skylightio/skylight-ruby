module Skylight
  module Messages
    class Annotation
      include Beefcake::Message

      optional :key,    :string,    1
      optional :int,    :int64,     2
      optional :double, :double,    3
      optional :string, :string,    4
      repeated :nested, Annotation, 5
    end
  end
end
