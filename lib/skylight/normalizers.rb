module Skylight
  # @api private
  # Convert AS::N events to Skylight events
  module Normalizers
    def self.registry
      @registry ||= {}
    end

    def self.register(name, klass, opts = {})
      enabled = opts[:enabled] != false
      registry[name] = [klass, enabled]
    end

    def self.unregister(name)
      @registry.delete(name)
    end

    def self.enable(*names, enabled: true)
      names.each do |name|
        matches = registry.select { |n, _| n =~ /(^|\.)#{name}$/ }
        raise ArgumentError, "no normalizers match #{name}" if matches.empty?

        matches.values.each { |v| v[1] = enabled }
      end
    end

    def self.disable(*names)
      enable(*names, enabled: false)
    end

    def self.build(config)
      normalizers = {}

      registry.each do |key, (klass, enabled)|
        next unless enabled

        unless klass.method_defined?(:normalize)
          # TODO: Warn
          next
        end

        normalizers[key] = klass.new(config)
      end

      Container.new(normalizers)
    end

    class Normalizer
      def self.register(name, opts = {})
        Normalizers.register(name, self, opts)
      end

      attr_reader :config

      include Util::Logging

      def initialize(config)
        @config = config
        setup if respond_to?(:setup)
      end

      def normalize(_trace, _name, _payload)
        :skip
      end

      def normalize_with_meta(trace, name, payload)
        # If we have a normal response but no meta, add it
        cat, title, desc, meta = ret = normalize(trace, name, payload)
        return cat if cat == :skip

        meta ||= {}
        process_meta(trace, name, payload, meta, cache_key: ret.hash)

        [cat, title, desc, meta]
      end

      def normalize_after(trace, span, name, payload); end

      private

        def process_meta(trace, name, payload, meta, cache_key: nil)
          trace.instrumenter.extensions.process_normalizer_meta(
            trace,
            name,
            payload,
            meta,
            cache_key: cache_key,
            **process_meta_options(payload)
          )
        end

        def process_meta_options(_payload)
          {}
        end
    end

    require "skylight/normalizers/default"
    DEFAULT = Default.new

    class Container
      def initialize(normalizers)
        @normalizers = normalizers
      end

      def keys
        @normalizers.keys
      end

      def normalize(trace, name, payload)
        normalizer_for(name).normalize_with_meta(trace, name, payload)
      end

      def normalize_after(trace, span, name, payload)
        normalizer_for(name).normalize_after(trace, span, name, payload)
      end

      def normalizer_for(name)
        # We never expect to hit the default case since we only register listeners
        # for items that we know have normalizers. For now, though, we'll play it
        # safe and provide a fallback.
        @normalizers.fetch(name, DEFAULT)
      end
    end

    %w[ action_controller/process_action
        action_controller/send_file
        action_dispatch/process_middleware
        action_view/render_collection
        action_view/render_partial
        action_view/render_template
        action_view/render_layout
        active_job/perform
        active_model_serializers/render
        active_record/instantiation
        active_record/sql
        active_storage
        active_support/cache
        coach/handler_finish
        coach/middleware_finish
        couch_potato/query
        data_mapper/sql
        elasticsearch/request
        faraday/request
        grape/endpoint
        graphiti/resolve
        graphiti/render
        graphql/base
        sequel/sql].each do |file|
      require "skylight/normalizers/#{file}"
    end
  end
end
