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
        # FIXME: make threadsafe
        return if enabled?(ext_name)
        return unless (ext_class = find_by_name(ext_name))

        extensions << ext_class.new(config)
      end

      def disable!(ext_name)
        # FIXME: make threadsafe
        return unless (ext_class = find_by_name(ext_name))

        extensions.reject! { |x| x.is_a?(ext_class) }
      end

      def enabled?(ext_name)
        return unless (ext_class = find_by_name(ext_name))

        !!extensions.detect { |x| x.is_a?(ext_class) }
      end

      # meta is a mutable hash that will be passed to the instrumenter.
      # This method bridges Skylight.instrument and instrumenter.instrument.
      def process_instrument_options(opts, meta)
        extensions.each do |ext|
          ext.process_instrument_options(opts, meta)
        end
      end

      def process_normalizer_meta(trace, name, payload, meta, **opts)
        extensions.each do |ext|
          ext.process_normalizer_meta(trace, name, payload, meta, **opts)
        end
      end

      def trace_preprocess_meta(meta)
        extensions.each do |ext|
          ext.trace_preprocess_meta(meta)
        end
      end

      # FIXME: cache?
      def allowed_meta_keys
        extensions.flat_map(&:allowed_meta_keys)
      end

      private

      attr_reader :extensions, :config

      def find_by_name(ext_name)
        Skylight::Extensions.const_get(
          ActiveSupport::Inflector.classify(ext_name)
        )
      rescue NameError
      end
    end

    class Extension
      def initialize(config)
        # FIXME: is it ok to share the config here, or does that create a circular reference?
        @config = config
      end

      def process_instrument_options(_, meta)
        meta
      end

      def process_normalizer_meta(trace, name, payload, meta, **opts)
        meta
      end

      def trace_preprocess_meta(_)
      end

      def allowed_meta_keys
        []
      end
    end

  end
end

require "skylight/extensions/source_location"
