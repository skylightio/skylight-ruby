module SpecHelper
  class MockGC
    def initialize
      @enabled = false
    end

    def enable
      @enabled = true
    end

    def enabled?
      @enabled
    end

    def total_time
      0
    end
  end

  def instrument(cat, *_args, &blk)
    ActiveSupport::Notifications.instrument(cat, {}, &blk)
  end

  def config
    @config ||= Skylight::Config.new(:test, test_config_values)
  end

  def agent_strategy
    "embedded"
  end

  def metrics_report_interval
    60
  end

  def log_path
    "-"
  end

  def test_config_values
    @test_config_values ||= {
      auth_http_connect_timeout: "2sec",
      auth_http_deflate: false,
      auth_http_read_timeout: "2sec",
      authentication: SecureRandom.uuid,
      daemon: { sockdir_path: sockdir_path, batch_flush_interval: "1sec" }.freeze,
      gc: { profiler: gc }.freeze,
      log_file: log_path,
      log_level: ENV["DEBUG"] ? :debug : :fatal,
      report_http_connect_timeout: "1sec",
      report_http_deflate: false,
      report_http_disabled: false,
      report_http_read_timeout: "1sec",
      user_config_path: tmp("user_config.yml")
    }.freeze

    @test_config_values.merge({
      report_url: "http://127.0.0.1:#{port}/report",
      auth_url: "http://127.0.0.1:#{port}/agent",
      app_create_url: "http://127.0.0.1:#{port}/apps",
      validation_url: "http://127.0.0.1:#{port}/agent/config",
    })
  end

  def gc
    @gc ||= MockGC.new
  end

  def start!
    stub_config_validation
    stub_session_request
    Skylight.start! config
  end

  def current_trace
    Skylight.instrumenter&.current_trace
  end

  def set_agent_env
    @_original_env = ENV.to_hash

    ENV["SKYLIGHT_AUTHENTICATION"] = test_config_values[:authentication]
    ENV["SKYLIGHT_BATCH_FLUSH_INTERVAL"] = "10ms"
    ENV["SKYLIGHT_REPORT_URL"] = "http://127.0.0.1:#{port}/report"
    ENV["SKYLIGHT_REPORT_HTTP_DEFLATE"] = "false"
    ENV["SKYLIGHT_AUTH_URL"] = "http://127.0.0.1:#{port}/agent"
    ENV["SKYLIGHT_VALIDATION_URL"] = "http://127.0.0.1:#{port}/agent/config"
    ENV["SKYLIGHT_AUTH_HTTP_DEFLATE"] = "false"

    # Experimental features
    ENV["SKYLIGHT_ENABLE_SOURCE_LOCATIONS"] = "true"

    if ENV["DEBUG"]
      ENV["SKYLIGHT_ENABLE_TRACE_LOGS"] = "true"
      ENV["SKYLIGHT_LOG_FILE"] = "-"
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
    # rubocop:disable Security/Eval
    begin
      stream = stream.to_s
      eval "$#{stream} = StringIO.new", nil, __FILE__, __LINE__ # $stdout = StringIO.new
      yield
      result = eval("$#{stream}", nil, __FILE__, __LINE__).string # $stdout.string
    ensure
      eval("$#{stream} = #{stream.upcase}", nil, __FILE__, __LINE__) # $stdout = STDOUT;
    end

    # rubocop:enable Security/Eval

    result
  end

  def with_sqlite_connection(database: nil)
    require "active_record"
    require "sqlite3"

    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: database || "file::memory:?cache=shared")

    yield
  ensure
    ActiveRecord::Base.remove_connection
  end

  def with_sqlite(migration: nil, database: nil)
    with_sqlite_connection(database: database) do
      verbose_was = ActiveRecord::Migration.verbose
      ActiveRecord::Migration.verbose = false
      ActiveRecord::Schema.define { migration.up } if migration
      yield
    ensure
      ActiveRecord::Migration.verbose = verbose_was
    end
  end

  def active_record_gte_61?
    defined?(ActiveRecord) && ActiveRecord.gem_version >= Gem::Version.new("6.1")
  end

  def active_record_transaction_title
    active_record_gte_61? ? "TRANSACTION" : "SQL"
  end
end
