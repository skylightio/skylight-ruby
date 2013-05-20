module Skylight
  module Messages
    class Annotation
      include Beefcake::Message

      optional :key,    String,     1
      optional :int,    :int64,     2
      optional :double, :double,    3
      optional :string, String,     4
      repeated :nested, Annotation, 5
    end
  end
end
