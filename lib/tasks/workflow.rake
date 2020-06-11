# frozen_string_literal: true

require "yaml"
require "json"
require "active_support/inflector"
require "digest"

# rubocop:disable Layout/HashAlignment
module WorkflowConfigGenerator
  def self.mongo
    { mongo: { image: "mongo:4.0", ports: ["27017:27017"] } }
  end

  # FIXME: hash this config and compare in the job
  TEST_JOBS = [
    {
      name: "mongo",
      ruby_version: "2.7",
      gemfile: "rails-5.2.x",
      services: mongo,
      env: {
        TEST_MONGO_INTEGRATION: "true",
        MONGO_HOST:             "localhost"
      }
    },

    {
      name: "mongoid-6",
      ruby_version: "2.7",
      gemfile: "rails-5.2.x",
      services: mongo,
      env: {
        TEST_MONGO_INTEGRATION: "true",
        MONGO_HOST: "localhost",
        MONGOID_VERSION: "~> 6.0"
      }
    },

    {
      name: "elasticsearch",
      ruby_version: "2.7",
      gemfile: "rails-5.2.x",
      services: {
        elasticsearch: {
          image: "elasticsearch:6.8.6",
          ports: %w[9200:9200 9300:9300],
          options: '-e "discovery.type=single-node"'
        }
      }
    },

    {
      ruby_version: "2.4",
      gemfile: "rails-5.2.x",
      env: {
        SIDEKIQ_VERSION: "~> 4",
        GRAPHQL_VERSION: "~> 1.7.0"
      }
    },

    {
      ruby_version: "2.7",
      gemfile: "rails-5.2.x",
      env: { GRAPHQL_VERSION: "~> 1.9.0" }
    },

    {
      ruby_version: "2.7",
      gemfile: "rails-5.2.x",
      env: { GRAPHQL_VERSION: "~> 1.8.0" }
    },

    {
      primary: true,
      ruby_version: "2.7",
      gemfile: "rails-6.0.x"
    },

    {
      ruby_version: "2.7",
      allow_failure: true,
      gemfile: "rails-edge",
      env: { AMS_VERSION: "edge" }
    },

    {
      ruby_version: "2.4",
      gemfile: "sinatra-1.4.x"
    },

    {
      ruby_version: "2.7",
      gemfile: "sinatra-1.4.x"
    },

    {
      ruby_version: "2.4",
      gemfile: "sinatra-2.0.x"
    },

    {
      ruby_version: "2.7",
      gemfile: "sinatra-2.0.x"
    },

    {
      ruby_version: "2.7",
      allow_failure: true,
      gemfile: "sinatra-edge"
    },

    {
      ruby_version: "2.4",
      gemfile: "grape",
      env: { RACK_VERSION: "~> 2.0.8" }
    },

    {
      ruby_version: "2.7",
      gemfile: "grape"
    },

    {
      ruby_version: "2.7",
      gemfile: "grape",
      env: {
        GRAPE_VERSION: "~> 0.13.0",
        RACK_VERSION: "~> 2.0.8"
      }
    },

    {
      ruby_version: "2.7",
      gemfile: "grape",
      env: {
        GRAPE_VERSION: "~> 1.1.0",
        RACK_VERSION: "~> 2.0.8"
      }
    },

    {
      ruby_version: "2.7",
      gemfile: "grape",
      env: {
        GRAPE_VERSION: "~> 1.2.0",
        RACK_VERSION: "~> 2.0.8"
      }
    },

    {
      ruby_version: "2.7",
      gemfile: "grape",
      env: {
        GRAPE_VERSION: "~> 1.3.0"
      }
    },

    {
      ruby_version: "2.7",
      allow_failure: true,
      gemfile: "grape",
      env: { GRAPE_VERSION: "edge" }
    },

    {
      ruby_version: "2.7",
      gemfile: "rails-5.2.x",
      env: { TILT_VERSION: "1.4.1" }
    },

    {
      ruby_version: "2.7",
      gemfile: "sinatra-1.4.x",
      env: { SEQUEL_VERSION: "4.34.0" }
    },

    {
      ruby_version: "2.7",
      gemfile: "rails-5.2.x",
      env: {
        AMS_VERSION: "~> 0.8.3",
        SIDEKIQ_VERSION: "none"
      }
    },

    {
      ruby_version: "2.7",
      gemfile: "rails-5.2.x",
      env: { AMS_VERSION: "~> 0.9.5" }
    },

    {
      ruby_version: "2.7",
      allow_failure: true,
      gemfile: "rails-5.2.x",
      env: { AMS_VERSION: "edge" }
    },

    {
      gemfile: "rails-edge",
      ruby_version: "2.8",
      allow_failure: true,
      container: {
        image: "rubocophq/ruby-snapshot:latest"
      },
      env: { RUBY_VERSION: "2.8.0-dev" }
    }
  ].freeze

  def self.to_json
    jobs = TEST_JOBS.map do |j|
      if j[:container]
        ContainerTestJob.new(j)
      else
        TestJob.new(j)
      end
    end

    primary = jobs.filter(&:primary?)
    raise "should only have one primary job" if primary.length != 1
    primary = primary.first

    (jobs - [primary]).each do |j|
      needs = (j.config[:needs] || []).concat([primary.id])
      j.update(needs: needs)
    end

    ids = jobs.map(&:id).each_with_object(Hash.new(0)) { |id, r| r[id] += 1 }
    repeated = ids.select { |_, v| v > 1 }

    unless ids.values.all? { |x| x == 1 }
      raise "jobs must have unique ids; #{repeated.keys.join(', ')} are repeated"
    end

    job_defs = jobs.map(&:to_template).inject(:merge)
    required = jobs.select(&:required?).map(&:id)

    job_defs.merge!(UploadCoverageJob.new({ needs: required }).to_template)
    job_defs.merge!(FinalizeJob.new({ needs: required }).to_template)

    template = {
      name: "Skylight Agent",
      env: DEFAULT_ENV,
      on: { pull_request: {}, push: { branches: ["master"] } },
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
    "EMBEDDED_HTTP_SERVER_TIMEOUT" =>  "30",
    "WORKER_SPAWN_TIMEOUT" => "15",
    "COVERAGE" => "true",
    "COVERAGE_DIR" => "${{ github.workspace }}/coverage",
    "DISABLED_COVERAGE_DIR" => "${{ github.workspace }}/coverage-disabled"
  }.freeze

  class BaseJob
    attr_reader :config

    def initialize(config)
      @config = config
    end

    def update(config)
      @config.merge!(config)
    end

    def primary?
      @config[:primary]
    end

    def to_template
      h = {
        name: decorated_name,
        "runs-on" => "ubuntu-latest",
      }

      h[:services] = config[:services] if config[:services]
      h[:env] = env if env
      h[:steps] = steps
      h[:needs] = config[:needs] if config[:needs]
      JSON.parse(JSON.generate({ id => h })) # ensure all keys stringified
    end

    def id
      ActiveSupport::Inflector.parameterize(name)
    end

    def name
      if env
        env_key = env.select { |k, _| k.to_s =~ /VERSION/ }.
                      map { |k, v| "#{k}=#{v}" }.
                      compact.
                      join(" ")
      end

      [
        "ruby #{ruby_version}",
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
      [].tap do |ary|
        ary << "[allowed to fail]" if allow_failure?
      end
    end

    def checkout_step
      {
        name: "Checkout",
        uses: "actions/checkout@v2"
      }
    end

    def setup_ruby_step
      {
        name: "Setup ruby",
        uses: "actions/setup-ruby@v1",
        with: {
          "ruby-version": ruby_version
        }
      }
    end

    def install_apt_dependencies_step
      {
        name: "Install APT dependencies",
        run: <<~RUN
          sudo apt-get update
          sudo apt-get install -yq sqlite libsqlite3-dev
        RUN
      }
    end

    def setup_cache_step
      {
        name: "Setup cache",
        uses: "actions/cache@v1",
        with: {
          path: "${{ github.workspace }}/vendor/bundle",
          key: "${{ runner.os }}-gems-#{ruby_version}-#{gemfile}",
          "restore-keys" => "${{ runner.os }}-gems-#{ruby_version}-"
        }
      }
    end

    def install_bundler_dependencies_step
      {
        name: "bundle install",
        run: <<~RUN
          gem install bundler
          bundle install
        RUN
      }
    end

    def run_tests_step
      {
        name: "Run tests",
        run: <<~RUN
          bundle exec rake workflow:verify[$CONFIG_DIGEST]
          bundle exec rake
        RUN
      }
    end

    def run_tests_disabled_agent_step
      {
        name: "Run tests (agent disabled)",
        env: {
          "COVERAGE_DIR" => DEFAULT_ENV.fetch("DISABLED_COVERAGE_DIR"),
          "SKYLIGHT_DISABLE_AGENT" => "true"
        },
        run: "bundle exec rake"
      }
    end

    def prepare_coverage_step
      # FIXME: replace uuidgen with static job id?
      {
        name: "Prepare coverage files for upload",
        run: <<~RUN
          mkdir -p coverage-sync/${{ github.run_id }}
          cp coverage/.resultset.json coverage-sync/${{ github.run_id }}/coverage.$(uuidgen).json
          cp coverage-disabled/.resultset.json coverage-sync/${{ github.run_id }}/coverage.disabled.$(uuidgen).json
        RUN
      }
    end

    def upload_coverage_step
      {
        name: "Upload coverage files",
        uses: "jakejarvis/s3-sync-action@v0.5.1",
        if: "success()",
        env: {
          AWS_S3_BUCKET: "direwolf-agent-github",
          AWS_ACCESS_KEY_ID: "${{ secrets.AWS_ACCESS_KEY_ID }}",
          AWS_SECRET_ACCESS_KEY: "${{ secrets.AWS_SECRET_ACCESS_KEY }}",
          SOURCE_DIR: "coverage-sync"
        }
      }
    end

    def ruby_version
      config.fetch(:ruby_version)
    end

    def gemfile
      config.fetch(:gemfile)
    end

    def gemfile_path
      "gemfiles/Gemfile.#{gemfile}"
    end

    def allow_failure?
      config.fetch(:allow_failure, false)
    end

    def env
      if config[:gemfile]
        { BUNDLE_GEMFILE: gemfile_path }.merge(config[:env] || {})
      else
        config[:env]
      end
    end
  end

  class TestJob < BaseJob
    def steps
      [
        checkout_step,
        setup_ruby_step,
        install_apt_dependencies_step,
        setup_cache_step,
        install_bundler_dependencies_step,
        run_tests_step,
        run_tests_disabled_agent_step,
        prepare_coverage_step,
        upload_coverage_step
      ].compact
    end
  end

  class ContainerTestJob < TestJob
    def steps
      [
        checkout_step,
        setup_cache_step,
        install_bundler_dependencies_step,
        run_tests_step,
        run_tests_disabled_agent_step
      ]
    end
  end

  class UploadCoverageJob < BaseJob
    def name
      "upload-coverage"
    end

    def steps
      [
        checkout_step,
        *setup_commit_metadata_steps,
        install_aws_cli_step,
        install_codeclimate_step,
        download_coverage_data_step,
        prepare_and_upload_coverage_data_step
      ]
    end

    def setup_commit_metadata_steps
      [
        {
          name: "Set up commit metadata (push)",
          if: "github.event_name == 'push'",
          env: {
            GIT_COMMIT_SHA: "${{ github.sha }}",
            GIT_BRANCH: "${{ github.ref }}"
          },
          run: <<~RUN
            echo "::set-env name=GIT_COMMIT_SHA::${GIT_COMMIT_SHA}"
            echo "::set-env name=GIT_BRANCH::${GIT_BRANCH/refs\/heads\//}"
          RUN
        },
        {
          name: "Set up commit metadata (pull_request)",
          if: "github.event_name == 'pull_request'",
          env: {
            GIT_COMMIT_SHA: "${{ github.event.pull_request.head.sha }}",
            GIT_BRANCH: "${{ github.event.pull_request.head.ref }}"
          },
          run: <<~RUN
            echo "::set-env name=GIT_COMMIT_SHA::${GIT_COMMIT_SHA}"
            echo "::set-env name=GIT_BRANCH::${GIT_BRANCH}"
          RUN
        }
      ]
    end

    def install_aws_cli_step
      {
        name: "Install AWS CLI",
        run: <<~RUN
          curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
          unzip awscliv2.zip
          sudo ./aws/install
        RUN
      }
    end

    def install_codeclimate_step
      {
        name: "Install Codeclimate test reporter",
        run: <<~RUN
          curl -L https://codeclimate.com/downloads/test-reporter/test-reporter-latest-linux-amd64 > ./cc-test-reporter
          chmod +x ./cc-test-reporter
        RUN
      }
    end

    def download_coverage_data_step
      {
        name: "Download coverage data",
        env: {
          AWS_ACCESS_KEY_ID: "${{ secrets.AWS_ACCESS_KEY_ID }}",
          AWS_SECRET_ACCESS_KEY: "${{ secrets.AWS_SECRET_ACCESS_KEY }}"
        },
        run: <<~RUN
          mkdir -p coverage
          mkdir -p formatted_coverage
          aws s3 sync s3://direwolf-agent-github/${{ github.run_id }} coverage
        RUN
      }
    end

    def prepare_and_upload_coverage_data_step
      {
        name: "Prepare and upload coverage",
        env: { CC_TEST_REPORTER_ID: "${{ secrets.CC_TEST_REPORTER_ID }}" },
        run: <<~RUN
          find coverage -name '*.json' | xargs -I % ./cc-test-reporter format-coverage -t simplecov -o formatted_coverage/% %
          ./cc-test-reporter sum-coverage formatted_coverage/**/*.json
          ./cc-test-reporter upload-coverage
        RUN
      }
    end
  end

  class FinalizeJob < BaseJob
    def initialize(*)
      super

      raise "FinalizeJob must have `:needs`" unless config[:needs]
    end

    def name
      "Required Tests Passed"
    end

    def steps
      [
        { name: "Mark tests passed", run: "true" }
      ]
    end
  end
end

namespace :workflow do
  desc "Generate the .github/workflow/build.yml config"
  task :generate do
    File.open(".github/workflows/build.yml", "w") do |f|
      f << "# WARNING: this file is written by a script. To make changes,\n"
      f << "# alter the config in lib/tasks/workflow.rake and \n"
      f << "# run `bundle exec rake workflow`.\n"
      f << WorkflowConfigGenerator.to_yaml
    end
  end

  desc "verify the config digest"
  task :verify, [:digest] do |t, args|
    WorkflowConfigGenerator.verify!(args.digest)
  end
end

desc "Generate the .github/workflow/build.yml config"
task workflow: ["workflow:generate"]
# rubocop:enable Layout/HashAlignment
