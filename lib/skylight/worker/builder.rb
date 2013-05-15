module Skylight
  module Worker
    class Builder
      def initialize(config = nil)
        @config = config
      end

      def spawn
        if jruby?
          raise NotImplementedError
        else
          Standalone.new(lockfile, sockfile_path, spawner)
        end
      end

    private

      def lockfile
        config(:lockfile) { File.join(sockfile_path, "skylight.pid") }.to_s
      end

      def sockfile_path
        config(:sockfile_path) { "tmp" }.to_s
      end

      def spawner
        config(:spawner) { Server }
      end

      def jruby?
        defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby'
      end

      def config(key, &blk)
        return blk.call unless @config
        @config[key] || blk.call
      end
    end
  end
end
