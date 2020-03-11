require "strscan"
require "securerandom"
require "skylight/util/logging"
require "skylight/util/lru_cache"

module Skylight
  # @api private
  class Instrumenter
    KEY = :__skylight_current_trace

    TOO_MANY_UNIQUES = "<too many unique descriptions>".freeze

    include Util::Logging

    class TraceInfo
      def initialize(key = KEY)
        @key = key
        @muted_key = "#{key}_muted"
      end

      def current
        Thread.current[@key]
      end

      def current=(trace)
        Thread.current[@key] = trace
      end

      # NOTE: This should only be set by the instrumenter, and only
      # in the context of a `mute` block. Do not try to turn this
      # flag on and off directly.
      def muted=(val)
        Thread.current[@muted_key] = val
      end

      def muted?
        !!Thread.current[@muted_key]
      end
    end

    attr_reader :uuid, :config, :gc

    def self.native_new(_uuid, _config_env)
      raise "not implemented"
    end

    def self.new(config)
      config.validate!

      uuid = SecureRandom.uuid
      inst = native_new(uuid, config.to_native_env)
      inst.send(:initialize, uuid, config)
      inst
    end

    def initialize(uuid, config)
      @uuid = uuid
      @gc = config.gc
      @config = config
      @subscriber = Skylight::Subscriber.new(config, self)

      @trace_info = @config[:trace_info] || TraceInfo.new(KEY)
      @mutex = Mutex.new

      @caller_cache = Util::LruCache.new(100)
      @instance_method_source_location_cache = Util::LruCache.new(100)
    end

    def log_context
      @log_context ||= { inst: uuid }
    end

    def native_start
      raise "not implemented"
    end

    def native_stop
      raise "not implemented"
    end

    def native_track_desc(_endpoint, _description)
      raise "not implemented"
    end

    def native_submit_trace(_trace)
      raise "not implemented"
    end

    def current_trace
      @trace_info.current
    end

    def current_trace=(trace)
      t { "setting current_trace=#{trace ? trace.uuid : 'nil'}; thread=#{Thread.current.object_id}" }
      @trace_info.current = trace
    end

    def check_install!
      # Warn if there was an error installing Skylight.

      if defined?(Skylight.check_install_errors)
        Skylight.check_install_errors(config)
      end

      if !Skylight.native? && defined?(Skylight.warn_skylight_native_missing)
        Skylight.warn_skylight_native_missing(config)
        return # rubocop:disable Style/RedundantReturn
      end
    end

    def muted=(val)
      @trace_info.muted = val
    end

    def muted?
      @trace_info.muted?
    end

    def mute
      old_muted = muted?
      self.muted = true
      yield if block_given?
    ensure
      self.muted = old_muted
    end

    def unmute
      old_muted = muted?
      self.muted = false
      yield if block_given?
    ensure
      self.muted = old_muted
    end

    def silence_warnings(context)
      @warnings_silenced || @mutex.synchronize do
        @warnings_silenced ||= {}
      end

      @warnings_silenced[context] = true
    end

    def warnings_silenced?(context)
      @warnings_silenced && @warnings_silenced[context]
    end

    alias disable mute
    alias disabled? muted?

    def start!
      # We do this here since we can't report these issues via Gem install without stopping install entirely.
      check_install!

      t { "starting instrumenter" }

      unless config.validate_with_server
        log_error "invalid config"
        return
      end

      t { "starting native instrumenter" }
      unless native_start
        warn "failed to start instrumenter"
        return
      end

      config.gc.enable
      @subscriber.register!

      ActiveSupport::Notifications.instrument("started_instrumenter.skylight", instrumenter: self)

      self
    rescue Exception => e
      log_error "failed to start instrumenter; msg=%s; config=%s", e.message, config.inspect
      t { e.backtrace.join("\n") }
      nil
    end

    def shutdown
      @subscriber.unregister!
      native_stop
    end

    def trace(endpoint, cat, title = nil, desc = nil, meta: nil, segment: nil, component: nil)
      # If a trace is already in progress, continue with that one
      if (trace = @trace_info.current)
        return yield(trace) if block_given?

        return trace
      end

      begin
        trace = Trace.new(self, endpoint, Skylight::Util::Clock.nanos, cat, title, desc,
                          meta: meta, segment: segment, component: component)
      rescue Exception => e
        log_error e.message
        t { e.backtrace.join("\n") }
        return
      end

      @trace_info.current = trace
      return trace unless block_given?

      begin
        yield trace
      ensure
        @trace_info.current = nil
        t { "instrumenter submitting trace; trace=#{trace.uuid}" }
        trace.submit
      end
    end

    def self.match?(string, regex)
      @scanner ||= StringScanner.new("")
      @scanner.string = string
      @scanner.match?(regex)
    end

    def match?(string, regex)
      self.class.match?(string, regex)
    end

    def instrument(cat, title = nil, desc = nil, meta = nil)
      raise ArgumentError, "cat is required" unless cat

      if muted?
        return yield if block_given?

        return
      end

      unless (trace = @trace_info.current)
        return yield if block_given?

        return
      end

      cat = cat.to_s

      unless match?(cat, Skylight::CATEGORY_REGEX)
        warn "invalid skylight instrumentation category; trace=%s; value=%s", trace.uuid, cat
        return yield if block_given?

        return
      end

      cat = "other.#{cat}" unless match?(cat, Skylight::TIER_REGEX)

      unless (sp = trace.instrument(cat, title, desc, meta))
        return yield if block_given?

        return
      end

      return sp unless block_given?

      begin
        yield sp
      rescue Exception => e
        meta ||= {}
        meta[:exception] = [e.class.name, e.message]
        meta[:exception_object] = e
        raise e
      ensure
        trace.done(sp, meta)
      end
    end

    def broken!
      return unless (trace = @trace_info.current)

      trace.broken!
    end

    def poison!
      @poisoned = true
    end

    def poisoned?
      @poisoned
    end

    def done(span, meta = nil)
      return unless (trace = @trace_info.current)

      trace.done(span, meta)
    end

    def limited_description(description)
      endpoint = @trace_info.current.endpoint

      if description
        if native_track_desc(endpoint, description)
          description
        else
          TOO_MANY_UNIQUES
        end
      end
    end

    def process(trace)
      t { fmt "processing trace=#{trace.uuid}" }

      if ignore?(trace)
        t { fmt "ignoring trace=#{trace.uuid}" }
        return false
      end

      begin
        finalize_endpoint_segment(trace)
        native_submit_trace(trace)
        true
      rescue => e
        handle_instrumenter_error(trace, e)
      end
    end

    def handle_instrumenter_error(trace, err)
      poison! if err.is_a?(Skylight::InstrumenterUnrecoverableError)

      warn "failed to submit trace to worker; trace=%s, err=%s", trace.uuid, err
      t { "BACKTRACE:\n#{err.backtrace.join("\n")}" }

      false
    end

    def ignore?(trace)
      config.ignored_endpoints.include?(trace.endpoint)
    end

    # Return [title, sql]
    def process_sql(sql)
      Skylight.lex_sql(sql)
    rescue SqlLexError => e
      if config[:log_sql_parse_errors]
        config.logger.error "[#{e.formatted_code}] Failed to extract binds from SQL query. " \
                            "It's likely that this query uses more advanced syntax than we currently support. " \
                            "sql=#{sql.inspect}"
      end
      nil
    end

    # Because GraphQL can return multiple results, each of which
    # may have their own success/error states, we need to set the
    # skylight segment as follows:
    #
    # - when all queries have errors: "error"
    # - when some queries have errors: "<rendered format>+error"
    # - when no queries have errors: "<rendered format>"
    #
    # <rendered format> will be determined by the Rails controller as usual.
    # See Instrumenter#finalize_endpoint_segment for the actual segment/error assignment.
    def finalize_endpoint_segment(trace)
      return unless (segment = trace.segment)

      segment = case trace.compound_response_error_status
                when :all
                  "error"
                when :partial
                  "#{segment}+error"
                else
                  segment
                end

      trace.endpoint += "<sk-segment>#{segment}</sk-segment>"
    end

    def gem_require_paths
      @gem_require_paths ||=
        Hash[*Bundler.load.specs.to_a.map { |s| s.full_require_paths.map { |p| [p, s.name] } }.flatten]
    end

    def find_caller(cache_key: nil)
      if cache_key && @caller_cache.key?(cache_key)
        return @caller_cache[cache_key]
      end

      # Start at file before this one
      caller_locations(1).find { |l| find_source_gem(l.absolute_path) || project_path?(l.absolute_path) }.tap do |loc|
        @caller_cache[cache_key] = loc if cache_key
      end
    end

    def find_source_gem(path)
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
      @instance_method_source_location_cache[[constant_name, method_name]] ||=
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
end
