require 'skylight/normalizers/default'

module Skylight
  # Convert AS::N events to Skylight events
  module Normalizers

    DEFAULT = Default.new

    def self.register(name, klass)
      (@registry ||= {})[name] = klass
      klass
    end

    def self.build(config)
      normalizers = {}

      (@registry || {}).each do |k, klass|
        unless klass.method_defined?(:normalize)
          # TODO: Warn
          next
        end

        normalizers[k] = klass.new(config)
      end

      Container.new(normalizers)
    end

    class Normalizer
      def self.register(name)
        Normalizers.register(name, self)
      end

      attr_reader :config

      def initialize(config)
        @config = config
        setup if respond_to?(:setup)
      end
    end

    class RenderNormalizer < Normalizer
      def setup
        @paths = config['normalizers.render.view_paths'] || []
      end

      def normalize_render(category, payload, annotations)
        if path = payload[:identifier]
          title = relative_path(path)
          path = nil if path == title
        end

        [ category, title, path, annotations ]
      end

      def relative_path(path)
        root = @paths.find { |p| path.start_with?(p) }

        if root
          relative = path[root.size..-1]
          relative = relative[1..-1] if relative.start_with?("/")
          relative
        else
          path
        end
      end
    end

    class Container
      def initialize(normalizers)
        @normalizers = normalizers
      end

      def normalize(trace, name, payload)
        normalizer = @normalizers[name] || DEFAULT
        normalizer.normalize(trace, name, payload)
      end
    end

    %w( process_action
        render_collection
        render_partial
        render_template
        send_file
        sql).each do |file|
      require "skylight/normalizers/#{file}"
    end
  end
end
