module SpecHelper
  module Messages
    class AnnotationVal
      include Beefcake::Message

      optional :uint_val, :uint64, 1
    end

    class Annotation
      # this is an Enum
      module AnnotationKey
        # rubocop:disable Naming/ConstantName
        ObjectAllocationRemainder = 1
        ObjectAllocationOffset = 2
        ObjectAllocationAbsoluteOffset = 1024
        ObjectAllocationCount = 1025
        # rubocop:enable Naming/ConstantName
      end

      include Beefcake::Message

      optional :key, AnnotationKey, 1
      optional :val, AnnotationVal, 4
    end
  end
end
