module Skylight
  module Worker
    class Builder
      include Util::Logging

      attr_reader :config

      def initialize(config = Config.new)
        if Hash === config
          config = Config.new(config)
        end

        @config = config
      end

      def build
        s = strategy.to_s

        case s
        when 'embedded'
          trace "building embedded worker"
          Embedded.new(Collector.new(config))
        when 'standalone'
          trace "building standalone worker"

          unless config[:'agent.sockfile_path']
            raise ConfigError, 'agent.sockfile_path required'
          end

          Standalone.new(
            config,
            lockfile,
            server)
        else
          # We can assume that if it's unknown it's from the config
          raise ConfigError, "unknown agent.strategy: `#{s}`"
        end
      end

    private

      def strategy
        config.get(:'agent.strategy') || default_strategy
      end

      def default_strategy
        ret = if jruby?
          'embedded'
        else
          'standalone'
        end

        ret.downcase.strip
      end

      def lockfile
        config.get(:'agent.lockfile') do
          name = [ 'skylight', config.environment ].compact.join('-')
          File.join(config[:'agent.sockfile_path'], "#{name}.pid")
        end.to_s
      end

      def server
        config.get(:'agent.server', Server)
      end

      def jruby?
        defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby'
      end

    end
  end
end
