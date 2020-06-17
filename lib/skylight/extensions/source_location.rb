# frozen_string_literal: true

require "skylight/util/lru_cache"

module Skylight
  module Extensions
    class SourceLocation < Extension
      attr_reader :config

      include Util::Logging

      META_KEYS = %i[source_location source_file source_line].freeze

      def initialize(*)
        super
        @caller_cache = Util::LruCache.new(100)
        @instance_method_source_location_cache = Util::LruCache.new(100)
      end

      def process_instrument_options(opts, meta)
        source_location = opts[:source_location] || opts[:meta]&.[](:source_location)
        source_file = opts[:source_file] || opts[:meta]&.[](:source_file)
        source_line = opts[:source_line] || opts[:meta]&.[](:source_line)

        if source_location
          meta[:source_location] = source_location
        elsif source_file
          meta[:source_file] = source_file
          meta[:source_line] = source_line
        else
          warn "Ignoring source_line without source_file" if source_line
          if (location = find_caller(cache_key: opts.hash))
            meta[:source_file] = location.absolute_path
            meta[:source_line] = location.lineno
          end
        end

        meta
      end

      # FIXME: why are we switching back and forth btw source_location and source_file/line?
      def process_normalizer_meta(trace, name, payload, meta, **opts)
        sl = if ((source_name, *args) = opts[:source_location])
               dispatch_hinted_source_location(
                 source_name,
                 trace,
                 name,
                 payload,
                 meta,
                 args: args, **opts
               )
             end

        sl ||= source_location(trace, name, payload, meta, cache_key: opts[:cache_key])

        if sl
          debug("normalizer source_location=#{sl}")
          meta[:source_file], meta[:source_line] = sl
        end

        meta
      end

      def trace_preprocess_meta(meta)
        source_line = meta.delete(:source_line)
        source_file = meta.delete(:source_file)

        if meta[:source_location]
          if source_file || source_line
            warn "Found both source_location and source_file or source_line, using source_location\n" \
                 "  location=#{meta[:source_location]}; file=#{source_file}; line=#{source_line}"
          end
        elsif source_file
          meta[:source_location] = sanitize_source_location(source_file, source_line)
        elsif source_line
          warn "Ignoring source_line without source_file; source_line=#{source_line}"
        end

        if meta[:source_location]
          debug("source_location=#{meta[:source_location]}")
        end
      end

      def allowed_meta_keys
        META_KEYS
      end

      protected

      def dispatch_hinted_source_location(source_name, trace, name, payload, meta, args:, **opts)
        if source_name == :instance_method
          const_name, method_name = args
          if const_name && method_name
            instance_method_source_location(const_name, method_name)
          end
        end
      end

      # from normalizers.rb
      # Returns an array of file and line
      def source_location(trace, _name, payload, meta, cache_key: nil)
        # FIXME: what should precedence be?
        if meta.is_a?(Hash) && meta[:source_location]
          meta.delete(:source_location)
        elsif payload.is_a?(Hash) && payload[:sk_source_location]
          payload[:sk_source_location]
        elsif (location = find_caller(cache_key: cache_key))
          [location.absolute_path, location.lineno]
        end
      end

      def gem_require_paths
        # FIXME threadsafe memoize
        @gem_require_paths ||=
          # FIXME: is it our responsibility or right to call Bundler.load?
          # FIXME: bundler is not a runtime dependency
          Hash[*Bundler.load.specs.to_a.map { |s| s.full_require_paths.map { |p| [p, s.name] } }.flatten]
      end

      def find_caller(cache_key: nil)
        if cache_key
          @caller_cache.fetch(cache_key) { find_caller_inner }
        else
          find_caller_inner
        end
      end

      def find_source_gem(path)
        # FIXME: remove ignored gems from require paths permanently
        _, name = gem_require_paths.find do |rpath, name|
          path.start_with?(rpath) && !config.source_location_ignored_gems.include?(name)
        end
        name
      end

      def project_path?(path)
        # Must be in the project root
        return false unless path.start_with?(config.root.to_s)
        # Must not be Bundler's vendor location
        return false if path.start_with?(Bundler.bundle_path.to_s)
        # Must not be Ruby files
        return false if path.include?("/ruby-#{RUBY_VERSION}/lib/ruby/")

        # So it must be a project file
        true
      end

      def instance_method_source_location(constant_name, method_name)
        @instance_method_source_location_cache.fetch([constant_name, method_name]) do
          if (constant = ::ActiveSupport::Dependencies.safe_constantize(constant_name))
            if constant.instance_methods.include?(:"before_instrument_#{method_name}")
              method_name = :"before_instrument_#{method_name}"
            end
            begin
              constant.instance_method(method_name).source_location
            rescue NameError
              nil
            end
          end
        end
      end

      def sanitize_source_location(path, line)
        # Do this first since gems may be vendored in the app repo. However, it might be slower.
        # Should we cache matches?
        if (gem_name = find_source_gem(path))
          path = gem_name
          line = nil
        elsif project_path?(path)
          # Get relative path to root
          path = Pathname.new(path).relative_path_from(config.root).to_s
        else
          return
        end

        line ? "#{path}:#{line}" : path
      end

      private

      def find_caller_inner
        # Start at file before this one
        caller_locations(1).find do |l|
          find_source_gem(l.absolute_path) || project_path?(l.absolute_path)
        end
      end
    end
  end
end
