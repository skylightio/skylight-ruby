module SpecHelper

  def instrument(cat, *args, &blk)
    ActiveSupport::Notifications.instrument(cat, {}, &blk)
  end

  def config
    @config ||= Skylight::Config.new(test_config_values)
  end

  def agent_strategy
    nil
  end

  def log_path
    '-'
  end

  def test_config_values
    @test_config_values ||= {
      authentication: "lulz",
      log: log_path,
      log_level: :debug,
      agent: {
        strategy: agent_strategy,
        interval: 1,
        sockfile_path: tmp
      }.freeze,
      report: {
        host: "localhost",
        port: port,
        ssl: false,
        deflate: false
      }.freeze,
      accounts: {
        host: "localhost",
        port: port,
        ssl: false,
        deflate: false
      }.freeze
    }.freeze
  end

end
