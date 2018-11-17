module Skylight::Core
  module Normalizers
    # Base Normalizer for Rails rendering
    class RenderNormalizer < Normalizer
      include Util::AllocationFree

      def setup
        @paths = config["normalizers.render.view_paths"] || []
      end

      # Generic normalizer for renders
      # @param category [String]
      # @param payload [Hash]
      # @option payload [String] :identifier
      # @return [Array]
      def normalize_render(category, payload)
        if path = payload[:identifier]
          title = relative_path(path)
          path = nil if path == title
        end

        [category, title, nil]
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

        if File.const_defined?(:NULL) ? File::NULL == "NUL" : RbConfig::CONFIG["host_os"] =~ /mingw|mswin32/
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
  end
end
