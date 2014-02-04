module Skylight
  module Messages
    class AnnotationBuilder
      def self.build(object)
        new(object).build
      end

      def initialize(object)
        @object = object
      end

      def build
        build_nested(@object)
      end

    private
      def build_nested(object)
        case object
        when Hash
          build_hash(object)
        when Array
          build_array(object)
        end
      end

      def build_hash(object)
        object.map do |key, value|
          build_annotation(value, key)
        end
      end

      def build_array(array)
        array.map do |value|
          build_annotation(value)
        end
      end

      def build_annotation(value, key=nil)
        Annotation.new.tap do |annotation|
          annotation.key = key.to_s if key
          annotation[classify(value)] = build_value(value)
        end
      end

      def build_value(value)
        nested?(value) ? build_nested(value) : value
      end

      def nested?(value)
        value.is_a?(Array) || value.is_a?(Hash)
      end

      def classify(value)
        case value
        when String
          :string
        when Integer
          :int
        when Numeric
          :double
        when Hash, Array
          :nested
        else
          raise Skylight::SerializeError.new("Annotation values must be Strings or Numeric. You passed #{value.inspect} in #{@object.inspect}")
        end
      end
    end

    class Span
      # Bit of a hack
      attr_accessor :absolute_time

      class Builder

        include Util::Logging

        attr_reader \
          :time,
          :category,
          :title,
          :started_at,
          :description,
          :annotations

        attr_accessor :children

        def initialize(trace, time, started_at, cat, title, desc, annot)
          @trace       = trace
          @built       = false
          @time        = time
          @started_at  = started_at
          @category    = cat.to_s
          @children    = 0
          @annotations = annot

          self.title   = title
          self.description = desc
        end

        def config
          @trace.config
        end

        def endpoint=(name)
          @trace.endpoint = name
        end

        def done
          @trace.done(self) unless built?
        rescue Exception => e
          error e.message
          t { e.backtrace.join("\n") }
        end

        def built?
          @built
        end

        def build(duration)
          @built = true
          Span.new(
            event: Event.new(
              category: category,
              title: title,
              description: description),
            annotations: to_annotations(annotations),
            started_at: @started_at,
            duration: duration && duration > 0 ? duration : nil,
            children: @children > 0 ? @children : nil)
        end

        def title=(val)
          val = nil unless val.respond_to?(:to_str)
          @title = val && val.to_str
        end

        def description=(val)
          val = nil unless val.respond_to?(:to_str)
          @description = val && val.to_str
        end

      private

        def to_annotations(val)
          return nil if !val || val.empty?

          AnnotationBuilder.build(val)
        end

      end
    end
  end
end
