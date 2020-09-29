module SpecHelper
  module Messages
    class Span
      include Beefcake::Message

      optional :parent,      :uint32,    1
      required :event,       Event,      2
      repeated :annotations, Annotation, 3
      required :started_at,  :uint32,    4
      optional :duration,    :uint32,    5

      def inspect
        super.gsub("SpecHelper::Messages::", "")
      end

      def annotation_val(key)
        key = SpecHelper::Messages::Annotation::AnnotationKey.const_get(key)
        annotation = annotations.find { |a| a.key == key }
        annotation&.val
      end
    end
  end
end
