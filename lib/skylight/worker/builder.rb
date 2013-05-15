module Skylight
  module Worker
    class Builder
      def initialize(config = nil)
        @config = nil
      end

      def spawn
        if jruby?
          raise NotImplementedError
        else
          Standalone.new(lockfile, sockfile_path)
        end
      end

    private

      def lockfile
        config(:lockfile) { File.join(sockfile_path, "skylight.pid") }
      end

      def sockfile_path
        config(:sockfile_path) { "tmp" }
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
