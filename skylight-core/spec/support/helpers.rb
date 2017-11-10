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

  def instrument(cat, *args, &blk)
    ActiveSupport::Notifications.instrument(cat, {}, &blk)
  end

  def config
    @config ||= Skylight::Core::Config.new(:test, test_config_values)
  end

  def agent_strategy
    'embedded'
  end

  def metrics_report_interval
    60
  end

  def log_path
    '-'
  end

  def test_config_values
    @test_config_values ||= {
      authentication: "lulz",
      log: log_path,
      log_level: :debug,
      user_config_path: tmp("user_config.yml"),
      report_url: "http://127.0.0.1:#{port}/report",
      report_http_deflate: false,
      report_http_connect_timeout: "1sec",
      report_http_read_timeout: "1sec",
      auth_url: "http://127.0.0.1:#{port}/agent",
      app_create_url: "http://127.0.0.1:#{port}/apps",
      validation_url: "http://127.0.0.1:#{port}/agent/config",
      auth_http_deflate: false,
      auth_http_connect_timeout: "2sec",
      auth_http_read_timeout: "2sec",
      gc: {
        profiler: gc
      }.freeze,
      daemon: {
        sockdir_path: sockdir_path,
        batch_flush_interval: "1sec"
      }.freeze,
    }.freeze
  end

  def gc
    @gc ||= MockGC.new
  end

  def start!
    stub_config_validation
    stub_session_request
    Skylight::Test.start! config
  end

  def current_trace
    inst = Skylight::Test.instrumenter
    inst ? inst.current_trace : nil
  end
end
