module SpecHelper
  module Messages
    class Span
      include Beefcake::Message

      optional :parent,      :uint32,    1
      required :event,       Event,      2
      repeated :annotations, Annotation, 3
      required :started_at,  :uint32,    4
      optional :duration,    :uint32,    5

      def ==(other)
        s = super
        return s if s || other == nil || other == false
        return s unless other[:annotations].nil? ^ self[:annotations].nil?

        # most specs don't specify annotations currently
        ::Kernel.warn "[WARNING] SpecHelper::Messages::Span ignoring annotations for equality check (#{__FILE__}:#{__LINE__})"

        fields.values.reject { |f| f.name == :annotations }.all? do |fld|
          self[fld.name] == other[fld.name]
        end
      end
    end
  end
end
