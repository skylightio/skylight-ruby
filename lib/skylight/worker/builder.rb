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
        if jruby?
          raise NotImplementedError
        else
          Standalone.new(
            lockfile,
            sockfile_path,
            server,
            keepalive.to_i)
        end
      end

    private

      def lockfile
        config.get('agent.lockfile') { File.join(sockfile_path, "skylight.pid") }.to_s
      end

      def sockfile_path
        config.get('agent.sockfile_path') { raise ArgumentError, "sockfile_path required" }.to_s
      end

      def server
        config.get('agent.server', Server)
      end

      def keepalive
        config.get('agent.keepalive', 60).to_i
      end

      def jruby?
        defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby'
      end

    end
  end
end
