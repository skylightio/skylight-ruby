module Skylight
  module Normalizers
    # Base Normalizer for Rails rendering
    class RenderNormalizer < Normalizer
      include Skylight::Util::AllocationFree

      def setup
        @paths = []

        Gem.path.each do |path|
          @paths << "#{path}/bundler/gems".freeze
          @paths << "#{path}/gems".freeze
          @paths << path
        end

        @paths.concat(Array(config["normalizers.render.view_paths"]))
      end

      # Generic normalizer for renders
      # @param category [String]
      # @param payload [Hash]
      # @option payload [String] :identifier
      # @return [Array]
      def normalize_render(category, payload)
        if (path = payload[:identifier])
          title = relative_path(path)
        end

        [category, title, nil]
      end

      def relative_path(path)
        return path if relative_path?(path)

        if (root = array_find(@paths) { |p| path.start_with?(p) })
          start = root.size
          start += 1 if path.getbyte(start) == SEPARATOR_BYTE

          path[start, path.size].sub(
            # Matches a Gem Version or 12-digit hex (sha)
            # that is preceeded by a `-` and followed by `/`
            # Also matches 'app/views/' if it exists
            %r{-(?:#{Gem::Version::VERSION_PATTERN}|[0-9a-f]{12})/(?:app/views/)*},
            ": ".freeze
          )
        else
          "Absolute Path".freeze
        end
      end

      private

      def relative_path?(path)
        !absolute_path?(path)
      end

      SEPARATOR_BYTE = File::SEPARATOR.ord

      if File.const_defined?(:NULL) ? File::NULL == "NUL" : RbConfig::CONFIG["host_os"] =~ /mingw|mswin32/
        # This is a DOSish environment
        ALT_SEPARATOR_BYTE = File::ALT_SEPARATOR&.ord
        COLON_BYTE = ":".ord
        SEPARATOR_BYTES = [SEPARATOR_BYTE, ALT_SEPARATOR_BYTE].freeze

        def absolute_path?(path)
          SEPARATOR_BYTES.include?(path.getbyte(2)) if alpha?(path.getbyte(0)) && path.getbyte(1) == COLON_BYTE
        end

        def alpha?(byte)
          (byte >= 65 && byte <= 90) || (byte >= 97 && byte <= 122)
        end
      else
        def absolute_path?(path)
          path.getbyte(0) == SEPARATOR_BYTE
        end
      end
    end
  end
end
