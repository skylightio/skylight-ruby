require 'skylight'
require 'rails'

module Skylight
  module Sinatra
    def self.registered(base)
      config = Skylight::Config.load(nil, ENV['RACK_ENV'], ENV)
      config['root'] = base.root
      config['agent.sockfile_path'] = File.join(config['root'], 'tmp')
      config.validate!

      Skylight.start!(config)

      base.use Skylight::Middleware
    end

    def route(verb, path, *)
      condition do
        trace = ::Skylight::Instrumenter.instance.current_trace
        base_path = request.script_name
        base_path = '' if base_path == '/'
        trace.endpoint = "#{verb} #{base_path}#{path}"
      end

      super
    end
  end
end
