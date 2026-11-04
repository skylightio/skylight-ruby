# frozen_string_literal: true

require "skylight/util/lru_cache"
require "active_support/inflector"

module Skylight
  module Extensions
    class SourceLocation < Extension
      attr_reader :config

      include Util::Logging

      META_KEYS = %i[source_location source_file source_line].freeze
      MAX_CALLER_DEPTH = 75

      # Upper bound for each path cache. These are keyed by file path, so in practice they're bounded by
      # the number of files that show up in backtraces; the limit only guards against pathological growth.
      PATH_CACHE_MAX_SIZE = 10_000

      def initialize(*)
        super
        cache_size = (config[:source_location_cache_size] || 1000).to_i
        @instance_method_source_location_cache = Util::LruCache.new(cache_size)

        # path (by value) => [sanitized_path, include_line] or false
        @path_info_cache = {}

        # Same as above, but keyed by object identity. Ruby interns the path of each loaded file,
        # so every backtrace location in a given file returns the same String object from
        # `absolute_path`, which makes this a cheap lookup while walking frames.
        @frame_path_info_cache = {}.compare_by_identity

        gem_require_trie # memoize this at startup
      end

      def process_trace_meta(meta)
        unless meta[:source_location] || meta[:source_file]
          warn "Ignoring source_line without source_file" if meta[:source_line]
          if (location = find_caller)
            meta[:source_file] = location.absolute_path
            meta[:source_line] = location.lineno
          end
        end
      end

      def process_instrument_options(opts, meta)
        source_location = opts[:source_location] || opts[:meta]&.[](:source_location)
        source_file = opts[:source_file] || opts[:meta]&.[](:source_file)
        source_line = opts[:source_line] || opts[:meta]&.[](:source_line)
        source_name_hint, const_name, method_name =
          opts[:source_location_hint] || opts[:meta]&.[](:source_location_hint)
        instrument_location = opts[:sk_instrument_location]

        if source_location
          meta[:source_location] = source_location
        elsif source_name_hint
          source_location = dispatch_hinted_source_location(source_name_hint, const_name, method_name)
          meta[:source_file], meta[:source_line] = source_location
          meta.delete(:source_location_hint) if source_location
        elsif source_file
          meta[:source_file] = source_file
          meta[:source_line] = source_line
        elsif instrument_location && project_path?(instrument_location.absolute_path)
          meta[:source_file] = instrument_location.absolute_path
          meta[:source_line] = instrument_location.lineno
        else
          warn "Ignoring source_line without source_file" if source_line
          if (location = find_caller)
            meta[:source_file] = location.absolute_path
            meta[:source_line] = location.lineno
          end
        end

        meta
      end

      def process_normalizer_meta(payload, meta, **opts)
        if opts[:source_location] && (opts[:source_file] || opts[:source_line])
          warn "Found both source_location and source_file or source_line in normalizer\n" \
                 "  location=#{opts[:source_location]}; file=#{opts[:source_file]}; line=#{opts[:source_line]}"
        end

        sl =
          if (source_name, constant_name, method_name = opts[:source_location_hint])
            dispatch_hinted_source_location(source_name, constant_name, method_name)
          elsif opts[:source_file]
            [opts[:source_file], opts[:source_line]]
          end

        sl ||= source_location(payload, meta)

        if sl
          t { "normalizer source_location=#{sl}" }
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

          unless meta[:source_location].is_a?(String)
            warn "Found non-string value for source_location; skipping"
            meta.delete(:source_location)
          end
        elsif source_file
          meta[:source_location] = sanitize_source_location(source_file, source_line)
        elsif source_line
          warn "Ignoring source_line without source_file; source_line=#{source_line}"
        end

        t { "source_location=#{meta[:source_location]}" } if meta[:source_location]
      end

      def allowed_meta_keys
        META_KEYS
      end

      protected

      def dispatch_hinted_source_location(source_name, const_name, method_name)
        return unless const_name && method_name

        instance_method_source_location(const_name, method_name, source_name: source_name)
      end

      # from normalizers.rb
      # Returns an array of file and line
      def source_location(payload, meta)
        # FIXME: what should precedence be?
        if meta.is_a?(Hash) && meta[:source_location]
          meta.delete(:source_location)
        elsif payload.is_a?(Hash) && payload[:sk_source_location]
          payload[:sk_source_location]
        elsif (location = find_caller)
          [location.absolute_path, location.lineno]
        end
      end

      # Returns the first location (starting at 4 to skip Skylight extension processing logic)
      # that is in a non-ignored gem or in the project.
      def find_caller
        ::Kernel.caller_locations(4..MAX_CALLER_DEPTH).find { |l| frame_path_info(l.absolute_path) }
      end

      def project_path?(path)
        return false unless path

        # Must be in the project root
        return false unless path.start_with?(config.root.to_s)

        # Must not be Bundler's vendor location
        return false if defined?(Bundler) && path.start_with?(Bundler.bundle_path.to_s)

        # Must not be Ruby files
        return false if path.include?("/ruby-#{RUBY_VERSION}/lib/ruby/")

        # So it must be a project file
        true
      end

      def instance_method_source_location(constant_name, method_name, source_name: :instance_method)
        @instance_method_source_location_cache.fetch([constant_name, method_name, source_name]) do
          if (constant = ::ActiveSupport::Inflector.safe_constantize(constant_name))
            if constant.instance_methods.include?(:"before_instrument_#{method_name}")
              method_name = :"before_instrument_#{method_name}"
            end
            begin
              unbound_method =
                case source_name
                when :instance_method
                  find_instance_method(constant, method_name)
                when :own_instance_method
                  find_own_instance_method(constant, method_name)
                when :instance_method_super
                  find_instance_method_super(constant, method_name)
                when :class_method
                  find_class_method(constant, method_name)
                end

              unbound_method&.source_location
            rescue NameError
              nil
            end
          end
        end
      end

      def sanitize_source_location(path, line)
        return unless (info = path_info(path))

        sanitized_path, include_line = info
        include_line && line ? "#{sanitized_path}:#{line}" : sanitized_path
      end

      private

      def path_info(path)
        return false unless path

        @path_info_cache.fetch(path) do
          @path_info_cache.clear if @path_info_cache.size >= PATH_CACHE_MAX_SIZE
          @path_info_cache[path] = compute_path_info(path)
        end
      end

      def frame_path_info(path)
        return false unless path

        @frame_path_info_cache.fetch(path) do
          @frame_path_info_cache.clear if @frame_path_info_cache.size >= PATH_CACHE_MAX_SIZE
          @frame_path_info_cache[path] = path_info(path)
        end
      end

      # Returns [sanitized_path, include_line], or false if the path should not be reported.
      # Gems are reported by name only; project files relative to the root, with a line number.
      def compute_path_info(path)
        # Do this first since gems may be vendored in the app repo.
        if (gem_name = find_source_gem(path))
          [gem_name, false].freeze
        elsif project_path?(path)
          [Pathname.new(path).relative_path_from(config.root).to_s.freeze, true].freeze
        else
          false
        end
      end

      def gem_require_trie
        @gem_require_trie ||=
          begin
            trie = {}

            Gem.loaded_specs.each do |name, spec|
              next if config.source_location_ignored_gems&.include?(name)

              spec.full_require_paths.each do |path|
                t1 = trie

                path
                  .split(File::SEPARATOR)
                  .each do |segment|
                    t1[segment] ||= {}
                    t1 = t1[segment]
                  end

                t1[:name] = name
              end
            end

            trie
          end
      end

      def find_source_gem(path)
        return nil unless path

        trie = gem_require_trie

        path
          .split(File::SEPARATOR)
          .each do |segment|
            trie = trie[segment]
            break unless trie
            return trie[:name] if trie[:name]
          end

        nil
      end

      # walks up the inheritance tree until it finds the last method
      # without a super_method definition.
      def find_instance_method_super(constant, method_name)
        return unless (unbound_method = find_instance_method(constant, method_name))

        unbound_method = unbound_method.super_method while unbound_method.super_method

        unbound_method
      end

      # walks up the inheritance tree until it finds the instance method
      # belonging to the constant given (skip prepended modules)
      def find_own_instance_method(constant, method_name)
        return unless (unbound_method = find_instance_method(constant, method_name))

        while unbound_method.owner != constant && unbound_method.super_method
          unbound_method = unbound_method.super_method
        end

        unbound_method if unbound_method.owner == constant
      end

      def find_instance_method(constant, method_name)
        constant.instance_method(method_name)
      end

      def find_class_method(constant, method_name)
        constant.method(method_name)
      end
    end
  end
end
