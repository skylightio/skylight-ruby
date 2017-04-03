require 'skylight/normalizers/default'

module Skylight
  # @api private
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

      def normalize(trace, name, payload)
        :skip
      end

      def normalize_after(trace, span, name, payload)
      end
    end

    class RenderNormalizer < Normalizer
      include Util::AllocationFree

      def setup
        @paths = config['normalizers.render.view_paths'] || []
      end

      def normalize_render(category, payload)
        if path = payload[:identifier]
          title = relative_path(path)
          path = nil if path == title
        end

        [ category, title, nil ]
      end

      def relative_path(path)
        return path if relative_path?(path)

        root = array_find(@paths) { |p| path.start_with?(p) }
        type = :project

        unless root
          root = array_find(Gem.path) { |p| path.start_with?(p) }
          type = :gem
        end

        if root
          start = root.size
          start += 1 if path.getbyte(start) == SEPARATOR_BYTE
          if type == :gem
            "$GEM_PATH/#{path[start, path.size]}"
          else
            path[start, path.size]
          end
        else
          "Absolute Path"
        end
      end

    private
      def relative_path?(path)
        !absolute_path?(path)
      end

      SEPARATOR_BYTE = File::SEPARATOR.ord

      if File.const_defined?(:NULL) ? File::NULL == "NUL" : RbConfig::CONFIG['host_os'] =~ /mingw|mswin32/
        # This is a DOSish environment
        ALT_SEPARATOR_BYTE = File::ALT_SEPARATOR && File::ALT_SEPARATOR.ord
        COLON_BYTE = ":".ord
        def absolute_path?(path)
          if alpha?(path.getbyte(0)) && path.getbyte(1) == COLON_BYTE
            byte2 = path.getbyte(2)
            byte2 == SEPARATOR_BYTE || byte2 == ALT_SEPARATOR_BYTE
          end
        end

        def alpha?(byte)
          byte >= 65 and byte <= 90 || byte >= 97 and byte <= 122
        end
      else
        def absolute_path?(path)
          path.getbyte(0) == SEPARATOR_BYTE
        end
      end
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
        @normalizers[name] || DEFAULT
      end
    end

    %w( action_controller/process_action
        action_controller/send_file
        action_view/render_collection
        action_view/render_partial
        action_view/render_template
        active_model_serializers/render
        active_record/sql
        active_support/cache
        elasticsearch/request
        grape/endpoint
        moped/query
        couch_potato/query).each do |file|
      require "skylight/normalizers/#{file}"
    end
  end
end
