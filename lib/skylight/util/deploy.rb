require 'json'
require 'uri'

module Skylight
  module Util

    module Deploy

      def self.build(config)
        DEPLOY_TYPES.each do |type|
          deploy = type.new(config)
          return deploy if deploy.id
        end
        nil
      end

      class EmptyDeploy

        attr_reader :config
        attr_reader :timestamp

        def initialize(config)
          @config = config
          @timestamp = Time.now.to_i
        end

        def id
          git_sha
        end

        def git_sha
          nil
        end

        def description
          nil
        end

        def to_query_string
          URI.encode_www_form(
            timestamp:   timestamp,
            deploy_id:   id.to_s[0..100], # Keep this sane
            git_sha:     git_sha[0..40], # A valid SHA will never exceed 40
            description: description[0..255]) # Avoid massive descriptions
        end

      end

      class DefaultDeploy < EmptyDeploy

        def id
          config.get(:'deploy.id') || git_sha
        end

        def git_sha
          config.get(:'deploy.git_sha')
        end

        def description
          config.get(:'deploy.description')
        end

      end

      class HerokuDeploy < EmptyDeploy

        def initialize(*)
          super
          @info = get_info
        end

        def id
          @info ? @info['id'] : nil
        end

        def git_sha
          @info ? @info['commit'] : nil
        end

        def description
          @info ? @info['description'] : nil
        end

        private

          def get_info
            info_path = config[:'heroku.dyno_info_path']

            if File.exist?(info_path)
              if info = JSON.parse(File.read(info_path))
                info['release']
              end
            end
          end

      end

      class GitDeploy < EmptyDeploy

        attr_reader :git_sha, :description

        def initialize(*)
          super
          @git_sha, @description = get_info
        end

        private

          def get_info
            Dir.chdir(config.root) do
              info = `git log -1 --pretty="%H %s" 2>&1`
              info.split(" ", 2).map(&:strip) if $?.success?
            end
          end

      end

      DEPLOY_TYPES = [DefaultDeploy, HerokuDeploy, GitDeploy]

    end

  end
end