module SpecHelper
  module Messages
    class AnnotationVal
      include Beefcake::Message

      optional :uint_val,   :uint64, 1
      optional :int_val,    :int64,  2 # Currently unused
      optional :double_val, :double, 3 # Currently unused
      optional :string_val, :string, 4
      repeated :nested,     AnnotationVal, 5 # Currently unused

      def to_s
        # only one of these should be present
        [@uint_val,
         @int_val,
         @double_val,
         @string_val,
         @nested].select { |x| x.present? }.join("; ")
      end
    end

    class Annotation
      # this is an Enum
      module AnnotationKey
        # rubocop:disable Naming/ConstantName
        ObjectAllocationRemainder = 1
        ObjectAllocationOffset = 2
        SourceLocation = 3

        ObjectAllocationAbsoluteOffset = 1024
        ObjectAllocationCount = 1025
        # rubocop:enable Naming/ConstantName
      end

      include Beefcake::Message

      optional :key, AnnotationKey, 1
      optional :val, AnnotationVal, 4

      # provide more readable messages when tests fail
      def inspect
        annotation_key = __beefcake_fields__[1]
        annotation_val = __beefcake_fields__[4]

        name = name_for(annotation_key.type, self[annotation_key.name])
        value = self[annotation_val.name]

        "#{name}=#{value}"
      end
    end
  end
end
