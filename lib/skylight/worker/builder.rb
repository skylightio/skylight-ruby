module Skylight
  module Worker
    class Builder
      attr_reader :config

      def initialize(config = Config.new)
        if Hash === config
          config = Config.new(config)
        end

        @config = config
      end

      def build
        s = strategy

        case s
        when 'embedded'
          Collector.new(config)
        when 'standalone'
          unless config[:'agent.sockfile_path']
            raise ArgumentError, 'agent.sockfile_path config required'
          end

          Standalone.new(
            config,
            lockfile,
            server)
        else
          raise "unknown strategy: `#{strat}`"
        end
      end

    private

      def strategy
        ret = config.get(:'agent.strategy') do
          if jruby?
            'embedded'
          else
            'standalone'
          end
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
