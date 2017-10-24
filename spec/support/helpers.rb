module SpecHelper

  def config
    @config ||= Skylight::Config.new(:test, test_config_values)
  end

end