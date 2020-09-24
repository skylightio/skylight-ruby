# frozen_string_literal: true

require "skylight/util/lru_cache"
require "active_support/dependencies"

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
        gem_require_trie # memoize this at startup
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

      def process_normalizer_meta(payload, meta, **opts)
        sl = if ((source_name, *args) = opts[:source_location])
               dispatch_hinted_source_location(
                 source_name,
                 payload,
                 meta,
                 args: args, **opts
               )
             end

        sl ||= source_location(payload, meta, cache_key: opts[:cache_key])

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

          unless meta[:source_location].is_a?(String)
            warn "Found non-string value for source_location; skipping"
            meta.delete(:source_location)
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

      def dispatch_hinted_source_location(source_name, _payload, _meta, args:, **_opts)
        const_name, method_name = args
        return unless const_name && method_name

        instance_method_source_location(const_name, method_name, source_name: source_name)
      end

      # from normalizers.rb
      # Returns an array of file and line
      def source_location(payload, meta, cache_key: nil)
        # FIXME: what should precedence be?
        if meta.is_a?(Hash) && meta[:source_location]
          meta.delete(:source_location)
        elsif payload.is_a?(Hash) && payload[:sk_source_location]
          payload[:sk_source_location]
        elsif (location = find_caller(cache_key: cache_key))
          [location.absolute_path, location.lineno]
        end
      end

      def find_caller(cache_key: nil)
        if cache_key
          @caller_cache.fetch(cache_key) { find_caller_inner }
        else
          find_caller_inner
        end
      end

      def project_path?(path)
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
          if (constant = ::ActiveSupport::Dependencies.safe_constantize(constant_name))
            if constant.instance_methods.include?(:"before_instrument_#{method_name}")
              method_name = :"before_instrument_#{method_name}"
            end
            begin
              unbound_method = case source_name
                               when :instance_method
                                 find_instance_method(constant, method_name)
                               when :own_instance_method
                                 find_own_instance_method(constant, method_name)
                               when :instance_method_super
                                 find_instance_method_super(constant, method_name)
                               end

              unbound_method&.source_location
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
          find_source_gem(path)
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

        def gem_require_trie
          @gem_require_trie ||= begin
            trie = {}

            Gem.loaded_specs.each do |name, spec|
              next if config.source_location_ignored_gems&.include?(name)

              spec.full_require_paths.each do |path|
                t1 = trie

                path.split(File::SEPARATOR).each do |segment|
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
          trie = gem_require_trie

          path.split(File::SEPARATOR).each do |segment|
            trie = trie[segment]
            break unless trie
            return trie[:name] if trie[:name]
          end

          nil
        end

        def find_caller_inner
          # Start at file before this one
          caller_locations(1).find do |l|
            find_source_gem(l.absolute_path) || project_path?(l.absolute_path)
          end
        end

        # walks up the inheritance tree until it finds the last method
        # without a super_method definition.
        def find_instance_method_super(constant, method_name)
          return unless (unbound_method = find_instance_method(constant, method_name))

          while unbound_method.super_method
            unbound_method = unbound_method.super_method
          end

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

    end
  end
end
