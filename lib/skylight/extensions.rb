# frozen_string_literal: true

require "active_support/inflector"

module Skylight
  module Extensions
    class Collection
      def initialize(config, extensions = [])
        @config = config
        @extensions = extensions
      end

      def enable!(ext_name)
        return if enabled?(ext_name)

        find_by_name(ext_name) do |ext_class|
          extensions << ext_class.new(config)
          rememoize!
        end
      end

      def disable!(ext_name)
        find_by_name(ext_name) do |ext_class|
          extensions.reject! { |x| x.is_a?(ext_class) }
          rememoize!
        end
      end

      def enabled?(ext_name)
        return unless (ext_class = find_by_name(ext_name))

        !!extensions.detect { |x| x.is_a?(ext_class) }
      end

      def process_trace_meta(meta)
        extensions.each do |ext|
          ext.process_trace_meta(meta)
        end
      end

      # meta is a mutable hash that will be passed to the instrumenter.
      # This method bridges Skylight.instrument and instrumenter.instrument.
      def process_instrument_options(opts, meta)
        extensions.each do |ext|
          ext.process_instrument_options(opts, meta)
        end
      end

      def process_normalizer_meta(payload, meta, **opts)
        extensions.each do |ext|
          ext.process_normalizer_meta(payload, meta, **opts)
        end
      end

      def trace_preprocess_meta(meta)
        extensions.each do |ext|
          ext.trace_preprocess_meta(meta)
        end
      end

      def allowed_meta_keys
        @allowed_meta_keys ||= extensions.flat_map(&:allowed_meta_keys).uniq
      end

      private

        attr_reader :extensions, :config

        def find_by_name(ext_name)
          begin
            Skylight::Extensions.const_get(
              ActiveSupport::Inflector.classify(ext_name)
            )
          rescue NameError
            return nil
          end.tap do |const|
            yield const if block_given?
          end
        end

        def rememoize!
          @allowed_meta_keys = nil
          allowed_meta_keys
        end
    end

    class Extension
      def initialize(config)
        @config = config
      end

      def process_trace_meta(_meta); end

      def process_instrument_options(_opts, _meta); end

      def process_normalizer_meta(_payload, _meta, **opts); end

      def trace_preprocess_meta(_meta); end

      def allowed_meta_keys
        []
      end
    end
  end
end

require "skylight/extensions/source_location"
