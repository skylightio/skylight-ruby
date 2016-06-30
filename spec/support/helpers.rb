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
    @config ||= Skylight::Config.new(:test, test_config_values)
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
      report_url: "http://localhost:#{port}/report",
      report_http_deflate: false,
      report_http_connect_timeout: "1sec",
      report_http_read_timeout: "1sec",
      auth_url: "http://localhost:#{port}/agent",
      app_create_url: "http://localhost:#{port}/apps",
      validation_url: "http://localhost:#{port}/agent/config",
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
    Skylight.start! config
  end

  def current_trace
    inst = Skylight::Instrumenter.instance
    inst ? inst.current_trace : nil
  end
end
