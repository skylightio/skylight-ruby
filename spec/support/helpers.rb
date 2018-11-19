module SpecHelper
  def config
    @config ||= Skylight::Config.new(:test, test_config_values)
  end

  def start!
    stub_config_validation
    stub_session_request
    Skylight.start! config
  end

  def current_trace
    inst = Skylight.instrumenter
    inst ? inst.current_trace : nil
  end

  def set_agent_env
    @_original_env = ENV.to_hash

    ENV["SKYLIGHT_AUTHENTICATION"]       = "lulz"
    ENV["SKYLIGHT_BATCH_FLUSH_INTERVAL"] = "1"
    ENV["SKYLIGHT_REPORT_URL"]           = "http://127.0.0.1:#{port}/report"
    ENV["SKYLIGHT_REPORT_HTTP_DEFLATE"]  = "false"
    ENV["SKYLIGHT_AUTH_URL"]             = "http://127.0.0.1:#{port}/agent"
    ENV["SKYLIGHT_VALIDATION_URL"]       = "http://127.0.0.1:#{port}/agent/config"
    ENV["SKYLIGHT_AUTH_HTTP_DEFLATE"]    = "false"
    ENV["SKYLIGHT_ENABLE_SEGMENTS"]      = "true"

    if ENV["DEBUG"]
      ENV["SKYLIGHT_ENABLE_TRACE_LOGS"]    = "true"
      ENV["SKYLIGHT_LOG_FILE"]             = "-"
      ENV["RUST_LOG"] = "skylight=debug"
    else
      ENV["SKYLIGHT_DISABLE_DEV_WARNING"] = "true"
    end

    if block_given?
      begin
        yield
      ensure
        restore_env!
      end
    end
  end

  def restore_env!
    return unless @_original_env
    ENV.replace(@_original_env)
    @_original_env = nil
  end

  def capture(stream)
    begin
      stream = stream.to_s
      eval "$#{stream} = StringIO.new", __FILE__, __LINE__
      yield
      result = eval("$#{stream}", __FILE__, __LINE__).string
    ensure
      eval("$#{stream} = #{stream.upcase}", __FILE__, __LINE__)
    end

    result
  end

  def with_sqlite
    ActiveRecord::Base.establish_connection({ adapter: 'sqlite3', database: ':memory:' })
    yield
    ActiveRecord::Base.remove_connection
  end
end
