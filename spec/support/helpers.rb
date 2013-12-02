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
    @config ||= Skylight::Config.new(test_config_values)
  end

  def agent_strategy
    'embedded'
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
        strategy:      agent_strategy,
        interval:      1,
        sockfile_path: tmp
      }.freeze,
      report: {
        host:    "localhost",
        port:    port,
        ssl:     false,
        deflate: false
      }.freeze,
      accounts: {
        host:    "localhost",
        port:    port,
        ssl:     false,
        deflate: false
      }.freeze,
      gc: {
        profiler: gc
      }.freeze,
      test: {
        constant_flush: true
      }
    }.freeze
  end

  def gc
    @gc ||= MockGC.new
  end

  def start!
    stub_session_request
    Skylight.start! config
  end

  def annotation(key=nil, type=nil, value=nil, &block)
    Skylight::Messages::Annotation.new.tap do |annotation|
      annotation.key = key if key
      annotation[type] = value if value

      if block_given?
        annotation.nested = []
        yield annotation.nested
      end
    end
  end
end
