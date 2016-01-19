require 'json'

module Skylight
  module Util

    module Deploy

      def self.detect_id(config)
        DEPLOY_TYPES.each do |type|
          if deploy_id = type.new(config).id
            return deploy_id
          end
        end
        nil
      end

      class EmptyDeploy

        attr_reader :config

        def initialize(config)
          @config = config
        end

        def id
          nil
        end

      end

      class DefaultDeploy < EmptyDeploy

        def id
          config.get(:deploy_id)
        end

      end

      class HerokuDeploy < EmptyDeploy

        def id
          if info = get_info
            info['release']['commit']
          end
        end

        private

          def get_info
            info_path = config[:'heroku.dyno_info_path']
            return nil unless File.exist?(info_path)
            JSON.parse(File.read(info_path))
          end

      end

      class GitDeploy < EmptyDeploy

        def id
          Dir.chdir(config.root) do
            rev = `git rev-parse HEAD 2>&1`
            rev.strip if $?.success?
          end
        end

      end

      DEPLOY_TYPES = [DefaultDeploy, HerokuDeploy, GitDeploy]

    end

  end
end