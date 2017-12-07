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

end