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
    ENV['SKYLIGHT_AUTHENTICATION']       = "lulz"
    ENV['SKYLIGHT_BATCH_FLUSH_INTERVAL'] = "1"
    ENV['SKYLIGHT_REPORT_URL']           = "http://127.0.0.1:#{port}/report"
    ENV['SKYLIGHT_REPORT_HTTP_DEFLATE']  = "false"
    ENV['SKYLIGHT_AUTH_URL']             = "http://127.0.0.1:#{port}/agent"
    ENV['SKYLIGHT_VALIDATION_URL']       = "http://127.0.0.1:#{port}/agent/config"
    ENV['SKYLIGHT_AUTH_HTTP_DEFLATE']    = "false"
    ENV['SKYLIGHT_ENABLE_SEGMENTS']      = "true"

    if ENV['DEBUG']
      ENV['SKYLIGHT_ENABLE_TRACE_LOGS']    = "true"
      ENV['SKYLIGHT_LOG_FILE']             = "-"
      ENV['RUST_LOG'] = "skylight=debug"
    else
      ENV['SKYLIGHT_DISABLE_DEV_WARNING'] = "true"
    end
  end

  def capture(stream)
    begin
      stream = stream.to_s
      eval "$#{stream} = StringIO.new"
      yield
      result = eval("$#{stream}").string
    ensure
      eval("$#{stream} = #{stream.upcase}")
    end

    result
  end

end