# frozen_string_literal: true

require "yaml"
require "json"
require "active_support/inflector"
require "digest"

OLDEST_RUBY = "2.7"
NEWEST_RUBY = "3.2"
HEAD_RUBY = "3.2"

module CITasks
  def self.mongo
    { mongo: { image: "mongo:4.0", ports: ["27017:27017"] } }
  end

  def self.redis
    {
      redis: {
        image: "redis",
        ports: ["6379:6379"],
        options: "--entrypoint redis-server"
      }
    }
  end

  GEMFILES_UPDATES = {
    "ams-0.8.x" => {
      allow: [{ "dependency-name": "active_model_serializers" }],
      ignore: [
        { "dependency-name": "active_model_serializers", versions: [">= 0.9"] }
      ]
    },
    "ams-0.9.x" => {
      allow: [{ "dependency-name": "active_model_serializers" }],
      ignore: [
        { "dependency-name": "active_model_serializers", versions: [">= 0.10"] }
      ]
    },
    "ams-0.10.x" => {
      allow: [{ "dependency-name": "active_model_serializers" }]
      # We don't limit this so that we're aware when new versions are released
    },
    "elasticsearch" => {
      allow: [{ "dependency-name": "elasticsearch" }]
      # We don't limit this so that we're aware when new versions are released
    },
    "grape-1.2.x" => {
      allow: [{ "dependency-name": "grape" }],
      ignore: [{ "dependency-name": "grape", versions: [">= 1.3"] }]
    },
    "grape-1.x" => {
      allow: [{ "dependency-name": "grape" }]
      # We don't limit this so that we're aware when new versions are released
    },
    "grape-edge" => {
      allow: [{ "dependency-name": "grape" }]
    },
    "graphql-1.8.x" => {
      allow: [{ "dependency-name": "graphql" }],
      ignore: [{ "dependency-name": "graphql", versions: [">= 1.9"] }]
    },
    "graphql-1.9.x" => {
      allow: [{ "dependency-name": "graphql" }],
      ignore: [{ "dependency-name": "graphql", versions: [">= 1.10"] }]
    },
    "mongoid-6.x" => {
      allow: [{ "dependency-name": "mongoid" }],
      ignore: [{ "dependency-name": "mongoid", versions: [">= 7"] }]
    },
    "mongoid-7.x" => {
      allow: [{ "dependency-name": "mongoid" }, { "dependency-name": "mongo" }]
      # We don't limit this so that we're aware when new versions are released
    },
    "rails-5.2.x" => {
      allow: [{ "dependency-name": "rails" }, { "dependency-name": "sqlite" }],
      ignore: [
        { "dependency-name": "rails", versions: [">= 5.3"] },
        { "dependency-name": "sqlite", versions: [">= 1.5"] }
      ]
    },
    "rails-6.0.x" => {
      allow: [{ "dependency-name": "rails" }],
      ignore: [{ "dependency-name": "rails", versions: [">= 6.1"] }]
    },
    "rails-6.1.x" => {
      allow: [{ "dependency-name": "rails" }]
      # We don't limit this so that we're aware when new versions are released
    },
    "rails-edge" => {
      allow: [{ "dependency-name": "rails" }]
    },
    "sequel-4.34.0" => {
      ignore: [{ "dependency-name": "*" }]
    },
    "sidekiq-4.x-graphql-1.7.x" => {
      allow: [
        { "dependency-name": "sidekiq" },
        { "dependency-name": "graphql" }
      ],
      ignore: [
        { "dependency-name": "sidekiq", versions: [">= 5"] },
        { "dependency-name": "graphql", versions: [">= 1.8"] }
      ]
    },
    "sinatra-1.x" => {
      allow: [{ "dependency-name": "sinatra" }],
      ignore: [{ "dependency-name": "sinatra", versions: [">= 1.5"] }]
    },
    "sinatra-2.x" => {
      allow: [{ "dependency-name": "sinatra" }]
      # We don't limit this so that we're aware when new versions are released
    },
    "sinatra-edge" => {
      allow: [{ "dependency-name": "sinatra" }]
    }
  }.freeze

  # FIXME: hash this config and compare in the job
  TEST_JOBS = [
    # Mongo gem with latest mongoid
    { primary: true, ruby_version: NEWEST_RUBY, gemfile: "default" },
    {
      name: "mongo",
      ruby_version: NEWEST_RUBY,
      gemfile: "rails-6.1.x",
      services: mongo,
      env: {
        TEST_MONGO_INTEGRATION: "true",
        MONGO_HOST: "localhost"
      }
    },
    # Oldest mongoid we support
    {
      name: "mongoid-6",
      ruby_version: "2.7",
      gemfile: "mongoid-6.x",
      services: mongo,
      env: {
        TEST_MONGO_INTEGRATION: "true",
        MONGO_HOST: "localhost"
      }
    },
    {
      name: "elasticsearch",
      ruby_version: NEWEST_RUBY,
      gemfile: "elasticsearch",
      services: {
        elasticsearch: {
          image: "elasticsearch:8.0.0",
          ports: %w[9200:9200 9300:9300],
          options:
            [
              "-e \"discovery.type=single-node\"",
              "-e \"xpack.security.enabled=false\"",
              "-e \"cluster.routing.allocation.disk.threshold_enabled=false\"",
              "--health-cmd \"curl --fail http://localhost:9200\"",
              "--health-interval 5s",
              "--health-retries 20"
            ].join(" ")
        }
      },
      env: {
        TEST_ELASTICSEARCH_INTEGRATION: "true"
      }
    },
    # GraphQL 1.7 is the oldest version that we support.
    # We also have some special handling for it.
    { ruby_version: OLDEST_RUBY, gemfile: "sidekiq-4.x-graphql-1.7.x" },
    # We need to test either 1.8 or 1.9 since there are more changes in 1.10.
    # We probably don't need to test both
    { ruby_version: "2.7", gemfile: "graphql-1.9.x" },
    # GraphQL 1.11 is tested as part of our default additional gems
    # TODO: We should test 1.12+

    { gemfile: "rails-5.2.x", ruby_version: OLDEST_RUBY, always_run: true },
    { always_run: true, ruby_version: NEWEST_RUBY, gemfile: "rails-6.0.x" },
    { always_run: true, ruby_version: NEWEST_RUBY, gemfile: "rails-6.1.x" },
    {
      ruby_version: NEWEST_RUBY,
      allow_failure: true,
      gemfile: "rails-edge",
      env: {
        # This is used in a spec
        RAILS_EDGE: true
      }
    },
    { ruby_version: OLDEST_RUBY, gemfile: "sinatra-1.x" },
    { always_run: true, ruby_version: NEWEST_RUBY, gemfile: "sinatra-2.x" },
    { ruby_version: NEWEST_RUBY, allow_failure: true, gemfile: "sinatra-edge" },
    { ruby_version: OLDEST_RUBY, gemfile: "grape-1.x" },
    { always_run: true, ruby_version: NEWEST_RUBY, gemfile: "grape-1.x" },
    # Oldest supported grape version. Doesn't support 3.0.
    { ruby_version: "2.7", gemfile: "grape-1.2.x" },
    { ruby_version: NEWEST_RUBY, allow_failure: true, gemfile: "grape-edge" },
    { ruby_version: NEWEST_RUBY, gemfile: "sequel-4.34.0" },
    { ruby_version: "2.7", gemfile: "ams-0.8.x" },
    { ruby_version: "2.7", gemfile: "ams-0.9.x" },
    { ruby_version: NEWEST_RUBY, gemfile: "ams-0.10.x" },
    {
      gemfile: "rails-6.1.x",
      ruby_version: HEAD_RUBY,
      ruby_install_version: "head",
      allow_failure: true
    },
    {
      gemfile: "rails-edge",
      ruby_version: HEAD_RUBY,
      ruby_install_version: "head",
      allow_failure: true,
      env: {
        # This is used in a spec
        RAILS_EDGE: true
      }
    }
  ].freeze

  module WorkflowConfigGenerator
    def self.to_json
      jobs =
        TEST_JOBS.map do |j|
          j[:container] ? ContainerTestJob.new(j) : TestJob.new(j)
        end

      primary = jobs.select(&:primary?)
      raise "should only have one primary job" if primary.length != 1

      primary = primary.first

      (jobs - [primary]).each do |j|
        needs = (j.config[:needs] || []).concat([primary.id])
        j.update(needs: needs)
      end

      ids = jobs.map(&:id).each_with_object(Hash.new(0)) { |id, r| r[id] += 1 }
      repeated = ids.select { |_, v| v > 1 }

      unless ids.values.all? { |x| x == 1 }
        raise "jobs must have unique ids; #{repeated.keys.join(", ")} are repeated"
      end

      job_defs = jobs.map(&:to_template).inject(:merge)
      required = jobs.select(&:required?).map(&:id)

      job_defs.merge!(LintJob.new.to_template)
      job_defs.merge!(FinalizeJob.new({ needs: required }).to_template)

      template = {
        name: "Skylight Agent",
        env: DEFAULT_ENV,
        on: {
          push: {
            branches: ["master"]
          },
          pull_request: {
            types: %w[labeled opened reopened synchronize]
          }
        },
        concurrency: {
          group: "ci-${{ github.ref }}",
          "cancel-in-progress": true
        },
        jobs: job_defs
      }

      JSON.generate(template)
    end

    def self.to_yaml
      json = to_json
      key = digest(json)
      config = JSON.parse(json)
      config["env"] ||= {}
      config["env"]["CONFIG_DIGEST"] = key
      config.to_yaml
    end

    def self.digest(str = to_json)
      Digest::SHA256.hexdigest(str)
    end

    def self.verify!(str)
      unless digest == str
        raise "digest does not match #{str}; " \
                "please run `rake workflow:generate` to update the config."
      end
    end

    DEFAULT_ENV = {
      "BUNDLE_PATH" => "${{ github.workspace }}/vendor/bundle",
      "SKYLIGHT_EXT_STRICT" => "false",
      "SKYLIGHT_REQUIRED" => "true",
      "SKYLIGHT_TEST_DIR" => "/tmp",
      "RAILS_ENV" => "development",
      "EMBEDDED_HTTP_SERVER_TIMEOUT" => "30",
      "WORKER_SPAWN_TIMEOUT" => "15"
    }.freeze

    class BaseJob
      attr_reader :config

      def initialize(config = {})
        @config = config
      end

      def update(config)
        @config.merge!(config)
      end

      def primary?
        @config[:primary]
      end

      def always_run?
        primary? || @config[:always_run]
      end

      def to_template_hash
        h = { :name => decorated_name, "runs-on" => "ubuntu-latest" }

        h["continue-on-error"] = true unless required?

        # If we're primary, really always run
        unless primary?
          conditions = [
            # On master
            "github.ref == 'refs/heads/master'",
            # Labeled with 'full-ci'
            "contains(github.event.pull_request.labels.*.name, 'full-ci')",
            # Labeled for dependency updates
            "contains(github.event.pull_request.labels.*.name, '#{gemfile_label}')"
          ]

          # Always run unless we're labeled with dependencies
          if always_run?
            conditions <<
              "!contains(github.event.pull_request.labels.*.name, 'dependencies')"
          end

          h[:if] = conditions.join(" || ")
        end

        h[:services] = (config[:services] || {}).merge(CITasks.redis)
        h[:env] = env if env
        h[:steps] = steps
        h[:needs] = config[:needs] if config[:needs]
        h
      end

      def to_template
        JSON.parse(JSON.generate({ id => to_template_hash })) # ensure all keys stringified
      end

      def id
        ActiveSupport::Inflector.parameterize(name)
      end

      def name
        if env
          env_key =
            env.select { |k, _| k.to_s =~ /VERSION/ }.map do |k, v|
              "#{k}=#{v}"
            end.compact.join(" ")
        end

        [
          "ruby #{ruby_install_version}",
          gemfile,
          config[:name],
          env_key && env_key.empty? ? nil : env_key
        ].compact.join(", ")
      end

      def required?
        !config[:allow_failure]
      end

      def decorated_name
        [*decorations, name].compact.join(" ")
      end

      private

      def decorations
        [].tap { |ary| ary << "[allowed to fail]" if allow_failure? }
      end

      def checkout_step
        { name: "Checkout", uses: "actions/checkout@v3" }
      end

      def setup_ruby_step
        {
          name: "Setup ruby",
          uses: "ruby/setup-ruby@v1",
          with: {
            "ruby-version": ruby_install_version
          }
        }
      end

      def check_ruby_step
        return if ruby_version == ruby_install_version

        { name: "Check ruby", run: "ruby -v | grep \"#{ruby_version}\" -q" }
      end

      def setup_volta_step
        { name: "Setup volta", uses: "volta-cli/action@v4" }
      end

      def install_apt_dependencies_step
        { name: "Install APT dependencies", run: <<~RUN }
              sudo apt-get update
              sudo apt-get install -yq sqlite libsqlite3-dev
            RUN
      end

      def setup_bundle_cache_step
        {
          name: "Setup cache (bundler)",
          uses: "actions/cache@v3",
          with: {
            :path => "${{ github.workspace }}/vendor/bundle",
            :key =>
              "${{ runner.os }}-gems-#{ruby_version}-#{gemfile}-${{ hashFiles('#{gemfile_path}.lock') }}",
            "restore-keys" =>
              "${{ runner.os }}-gems-#{ruby_version}-#{gemfile}-\n" \
                "${{ runner.os }}-gems-#{ruby_version}-"
          }
        }
      end

      def setup_yarn_cache_step
        [
          {
            name: "Get yarn cache directory path",
            id: "yarn-cache-dir-path",
            run: "echo \"::set-output name=dir::$(yarn cache dir)\""
          },
          {
            name: "Setup cache (yarn)",
            uses: "actions/cache@v3",
            with: {
              path: "${{ steps.yarn-cache-dir-path.outputs.dir }}",
              key: "${{ runner.os }}-yarn-${{ hashFiles('**/yarn.lock') }}",
              "restore-keys": "${{ runner.os }}-yarn-"
            }
          }
        ]
      end

      def install_bundler_dependencies_step
        { name: "bundle install", run: <<~RUN }
              gem install bundler
              bundle install
            RUN
      end

      def install_yarn_dependencies_step
        { name: "yarn install", run: "yarn install --frozen-lockfile" }
      end

      def run_tests_step
        { name: "Run tests", run: <<~RUN }
              bundle exec rake workflow:verify[$CONFIG_DIGEST]
              bundle exec rake
            RUN
      end

      def run_tests_disabled_agent_step
        {
          name: "Run tests (agent disabled)",
          env: {
            "SKYLIGHT_DISABLE_AGENT" => "true"
          },
          run: "bundle exec rake"
        }
      end

      def ruby_version
        config.fetch(:ruby_version)
      end

      def ruby_install_version
        config.fetch(:ruby_install_version) { ruby_version }
      end

      def gemfile
        config.fetch(:gemfile, "default")
      end

      def gemfile_label
        config.fetch(:gemfile, "default-Gemfile")
      end

      def gemfile_path
        gemfile == "default" ? "Gemfile" : "gemfiles/#{gemfile}/Gemfile"
      end

      def allow_failure?
        config.fetch(:allow_failure, false)
      end

      def env
        if gemfile == "default"
          config[:env]
        else
          { BUNDLE_GEMFILE: gemfile_path }.merge(config[:env] || {})
        end
      end
    end

    class TestJob < BaseJob
      def steps
        [
          checkout_step,
          setup_ruby_step,
          check_ruby_step,
          install_apt_dependencies_step,
          setup_bundle_cache_step,
          install_bundler_dependencies_step,
          run_tests_step,
          run_tests_disabled_agent_step
        ].flatten.compact
      end
    end

    # We don't use this right now
    class ContainerTestJob < TestJob
      def steps
        [
          checkout_step,
          check_ruby_step,
          setup_bundle_cache_step,
          install_bundler_dependencies_step,
          run_tests_step,
          run_tests_disabled_agent_step
        ].flatten.compact
      end
    end

    class LintJob < BaseJob
      def name
        "lint"
      end

      def always_run?
        true
      end

      def ruby_version
        "2.7" # Oldest version that works with Rails 7
      end

      def gemfile
        "rails-6.1.x"
      end

      def to_template_hash
        super.merge(if: "always()")
      end

      def steps
        [
          checkout_step,
          setup_ruby_step,
          setup_volta_step,
          setup_bundle_cache_step,
          setup_yarn_cache_step,
          install_bundler_dependencies_step,
          install_yarn_dependencies_step,
          setup_lint_matchers,
          run_prettier_step,
          run_rubocop_step
        ].flatten.compact
      end

      private

      def setup_lint_matchers
        # ::add-matcher is documented here:
        # https://github.com/actions/toolkit/blob/master/docs/commands.md#problem-matchers
        {
          name: "Set up Rubocop problem matcher",
          run:
            "echo \"::add-matcher::${GITHUB_WORKSPACE}/.github/rubocop.json\""
        }
      end

      def run_prettier_step
        { name: "Run Prettier", run: "yarn lint:prettier" }
      end

      def run_rubocop_step
        { name: "Run Rubocop", run: <<~RUN }
              bundle exec rubocop -v
              bundle exec rubocop
            RUN
      end
    end

    class FinalizeJob < BaseJob
      def initialize(*)
        super

        raise "FinalizeJob must have `:needs`" unless config[:needs]
      end

      def always_run?
        true
      end

      def to_template_hash
        super.merge(if: "always()")
      end

      def name
        "Required Tests Passed"
      end

      def steps
        [
          {
            name: "Mark tests failed",
            run: "false",
            if: "contains(needs.*.result, 'failure')"
          },
          {
            name: "Mark tests passed",
            run: "true",
            if: "!contains(needs.*.result, 'failure')"
          }
        ]
      end
    end
  end

  class DependabotConfigGenerator
    def self.to_yaml
      gemfiles =
        TEST_JOBS.map { |j| j[:gemfile] }.compact.uniq.reject do |g|
          g == "default"
        end

      bundler_config = {
        "package-ecosystem" => "bundler",
        "directory" => "/",
        "schedule" => {
          "interval" => "weekly",
          "time" => "13:00"
        },
        "labels" => %w[dependencies default-Gemfile],
        "open-pull-requests-limit" => 10
      }

      actions_config = {
        "package-ecosystem" => "github-actions",
        "directory" => "/",
        "schedule" => {
          "interval" => "weekly",
          "time" => "13:00"
        },
        "open-pull-requests-limit" => 10
      }

      config = { "version" => 2, "updates" => [bundler_config, actions_config] }

      gemfile_configs =
        gemfiles.map do |g|
          gc =
            bundler_config.merge(
              "directory" => "gemfiles/#{g}",
              "labels" => ["dependencies", g]
            )

          if (gemfile_updates = GEMFILES_UPDATES[g])
            gc.merge!(gemfile_updates)
          end

          gc
        end

      config["updates"].concat(gemfile_configs)

      # HACK: Converting to json prevents YAML aliases which Github doesn't like
      YAML.safe_load(config.to_json).to_yaml
    end
  end
end

namespace :workflow do
  desc "Generate the .github/workflow/build.yml config"
  task :generate do
    File.open(".github/workflows/build.yml", "w") do |f|
      f << "# WARNING: this file is written by a script. To make changes,\n"
      f << "# alter the config in lib/tasks/ci.rake and\n"
      f << "# run `bundle exec rake workflow`.\n"
      f << CITasks::WorkflowConfigGenerator.to_yaml
    end
  end

  desc "verify the config digest"
  task :verify, [:digest] do |_t, args|
    CITasks::WorkflowConfigGenerator.verify!(args.digest)
  end
end

desc "Generate the .github/dependabot.yml config"
task :dependabot do
  File.open(".github/dependabot.yml", "w") do |f|
    f << "# WARNING: this file is written by a script. To make changes,\n"
    f << "# alter the config in lib/tasks/ci.rake and\n"
    f << "# run `bundle exec rake dependabot`.\n"
    f << CITasks::DependabotConfigGenerator.to_yaml
  end
end

desc "Generate the .github/workflow/build.yml config"
task workflow: ["workflow:generate", :dependabot]
