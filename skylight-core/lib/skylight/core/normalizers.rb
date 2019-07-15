require "skylight/core/normalizers/default"

module Skylight::Core
  # @api private
  # Convert AS::N events to Skylight events
  module Normalizers
    DEFAULT = Default.new

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

      def initialize(config)
        @config = config
        setup if respond_to?(:setup)
      end

      def normalize(_trace, _name, _payload)
        :skip
      end

      def normalize_after(trace, span, name, payload); end
    end

    class Container
      def initialize(normalizers)
        @normalizers = normalizers
      end

      def keys
        @normalizers.keys
      end

      def normalize(trace, name, payload)
        normalizer_for(name).normalize(trace, name, payload)
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
        moped/query
        sequel/sql].each do |file|
      require "skylight/core/normalizers/#{file}"
    end
  end
end
