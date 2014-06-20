require 'skylight'

module Skylight
  module Sinatra
    def self.registered(base)
      config = Skylight::Config.load(nil, base.environment, ENV)
      config['root'] = base.root
      config['agent.sockfile_path'] ||= File.join(config['root'], 'tmp')
      config.validate!

      base.enable :skylight

      Skylight.start!(config)

      base.use Skylight::Middleware
    rescue ConfigError => e
      puts "[SKYLIGHT] [#{Skylight::VERSION}] #{e.message}; disabling Skylight agent"
      base.disable :skylight
    end

    def route(verb, path, *)
      if skylight?
        condition do
          trace = ::Skylight::Instrumenter.instance.current_trace
          trace.endpoint = "#{verb} #{uri(path, false)}"

          true
        end
      end

      super
    end
  end
end
