require "spec_helper"

module Skylight
  describe Config do
    def with_file(opts = {})
      f = Tempfile.new("foo")
      FileUtils.chmod 0400, f if opts[:writable] == false
      yield f
    ensure
      f.close
      f.unlink
    end

    def with_dir(opts = {})
      Dir.mktmpdir do |d|
        FileUtils.mkdir("#{d}/nested")
        FileUtils.chmod 0400, "#{d}/nested" if opts[:writable] == false
        yield "#{d}/nested"
      end
    end

    context "hostname" do
      it "defaults to the current hostname" do
        config = Config.new
        expect(config[:hostname]).to eq(Socket.gethostname)
      end

      it "can be overridden" do
        config = Config.new hostname: "lulz"
        expect(config[:hostname]).to eq("lulz")
      end
    end

    context "deploy" do
      it "uses provided deploy" do
        config = Config.new deploy: { id: "12345", git_sha: "19a8cfc47c10d8069916ae8adba0c9cb4c6c572d", description: "Fix stuff" }
        expect(config.deploy.id).to eq("12345")
        expect(config.deploy.git_sha).to eq("19a8cfc47c10d8069916ae8adba0c9cb4c6c572d")
        expect(config.deploy.description).to eq("Fix stuff")
      end

      it "uses sha if no id provided" do
        config = Config.new deploy: { git_sha: "19a8cfc47c10d8069916ae8adba0c9cb4c6c572d" }
        expect(config.deploy.id).to eq("19a8cfc47c10d8069916ae8adba0c9cb4c6c572d")
      end

      it "converts to query string" do
        Timecop.freeze Time.at(1452620644) do
          config = Config.new deploy: {
            id: "1234567890abcdefghijklmnopqrstuvwxyz1234567890abcdefghijklmnopqrstuvwxyz1234567890abcdefghijklmnopqrstuvwxyz",
            git_sha: "19a8cfc47c10d8069916ae8adba0c9cb4c6c572dwhat?",
            description: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et " \
                          "dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut " \
                          "aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse " \
                          "cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in " \
                          "culpa qui officia deserunt mollit anim id est laborum."
          }

          expect(config.deploy.to_query_hash).to eq({
            timestamp: 1452620644,
            deploy_id: "1234567890abcdefghijklmnopqrstuvwxyz1234567890abcdefghijklmnopqrstuvwxyz1234567890abcdefghijklmnopqrs",
            git_sha:   "19a8cfc47c10d8069916ae8adba0c9cb4c6c572dw",
            description: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore " \
                          "et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut " \
                          "aliquip ex ea commodo consequat. Duis aute irure dolor in"
          })
        end
      end

      it "only requires the id" do
        Timecop.freeze Time.at(1452620644) do
          config = Config.new deploy: {
            id: "1234567890abcdefghijklmnopqrstuvwxyz1234567890abcdefghijklmnopqrstuvwxyz1234567890abcdefghijklmnopqrstuvwxyz"
          }

          expect(config.deploy.to_query_hash).to eq({
            timestamp: 1452620644,
            deploy_id: "1234567890abcdefghijklmnopqrstuvwxyz1234567890abcdefghijklmnopqrstuvwxyz1234567890abcdefghijklmnopqrs"
          })
        end
      end

      it "detects Heroku" do
        config = Config.new 'heroku.dyno_info_path': File.expand_path("../../skylight-core/spec/support/heroku_dyno_info_sample", __dir__)
        expect(config.deploy.id).to eq(123)
        expect(config.deploy.git_sha).to eq("19a8cfc47c10d8069916ae8adba0c9cb4c6c572d")
        expect(config.deploy.description).to eq("Deploy 19a8cfc")
      end

      context "with a git repo" do
        around :each do |example|
          Dir.mktmpdir do |dir|
            @dir = dir
            Dir.chdir(dir) do
              system("git init > /dev/null")
              system('git config --global user.email "you@example.com" > /dev/null')
              system('git config --global user.name "Your Name" > /dev/null')
              system("git commit -m \"Initial Commit\n\nMore info\" --allow-empty > /dev/null")
              @sha = `git rev-parse HEAD`.strip
              example.run
            end
          end
        end

        it "detects git" do
          config = Config.new(root: @dir)

          # This will be the agent repo's current SHA
          expect(config.deploy.git_sha).to match(/^[a-f0-9]{40}$/)
          expect(config.deploy.git_sha).to eq(@sha)

          # Id should match SHA
          expect(config.deploy.id).to eq(@sha)

          expect(config.deploy.description).to eq("Initial Commit")
        end
      end

      context "without a detectable deploy" do
        around :each do |example|
          Dir.mktmpdir do |dir|
            Dir.chdir(dir) do
              example.run
            end
          end
        end

        it "returns nil" do
          config = Config.new
          expect(config.deploy).to be_nil
        end
      end
    end

    context "validations" do
      let :config do
        Config.new(authentication: "testtoken")
      end

      it "does not allow agent.interval to be a non-zero integer" do
        expect {
          config["agent.interval"] = "abc"
        }.to raise_error(Core::ConfigError, "invalid value for agent.interval (abc), must be an integer greater than 0")

        expect {
          config["agent.interval"] = -1
        }.to raise_error(Core::ConfigError, "invalid value for agent.interval (-1), must be an integer greater than 0")

        expect {
          config["agent.interval"] = 5
        }.to_not raise_error
      end

      context "permissions" do
        it "requires the pidfile_path file to be writeable if it exists" do
          with_file(writable: false) do |f|
            config.set(:'daemon.pidfile_path', f.path)

            expect {
              config.validate!
            }.to raise_error(Core::ConfigError, "File `#{f.path}` is not writable. Please set daemon.pidfile_path or daemon.sockdir_path in your config to a writable path")
          end
        end

        it "requires the pidfile_path directory to be writeable if file doesn't exist" do
          with_dir(writable: false) do |d|
            config.set(:'daemon.pidfile_path', "#{d}/bar")

            expect {
              config.validate!
            }.to raise_error(Core::ConfigError, "Directory `#{d}` is not writable. Please set daemon.pidfile_path or daemon.sockdir_path in your config to a writable path")
          end
        end

        it "requires the sockdir_path to be writeable" do
          with_dir(writable: false) do |d|
            config.set(:'daemon.sockdir_path', d)
            config.set(:'daemon.pidfile_path', "~/skylight.pid") # Otherwise based on sockdir_path and will error first

            expect {
              config.validate!
            }.to raise_error(Core::ConfigError, "Directory `#{d}` is not writable. Please set daemon.sockdir_path in your config to a writable path")
          end
        end
      end
    end

    context "#to_native_env" do
      let :config do
        Config.new(
          authentication: "abc123",
          hostname:  "test.local",
          root:      "/tmp",

          # These are set in some envs and not others
          "daemon.ssl_cert_dir" => nil,
          "daemon.ssl_cert_path" => nil,
          "daemon.exec_path" => nil,
          "daemon.lib_path" => nil,

          # Make sure the false value gets passed to the native env (true is default)
          "daemon.lazy_start" => false
        )
      end

      def get_env
        Hash[*config.to_native_env]
      end

      it "converts to env" do
        expect(get_env).to eq({
          # (Includes default component info)
          "SKYLIGHT_AUTHENTICATION" => "abc123|component=web%3Aproduction&reporting_env=true",
          "SKYLIGHT_VERSION"    => Skylight::VERSION,
          "SKYLIGHT_ROOT"       => "/tmp",
          "SKYLIGHT_HOSTNAME"   => "test.local",
          "SKYLIGHT_AUTH_URL"   => "https://auth.skylight.io/agent",
          "SKYLIGHT_LAZY_START" => "false",
          "SKYLIGHT_VALIDATE_AUTHENTICATION" => "false",
        })
      end

      it "includes deploy info if available" do
        config[:'deploy.id'] = "d456"

        # (Includes default component info)
        Timecop.freeze do
          expect(get_env["SKYLIGHT_AUTHENTICATION"]).to \
            eq("abc123|timestamp=#{Time.now.to_i}&deploy_id=d456&component=web%3Aproduction&reporting_env=true")
        end
      end

      it "includes keys only if value is set" do
        expect(get_env["SKYLIGHT_SESSION_TOKEN"]).to be_nil

        config[:session_token] = "zomg"

        expect(get_env["SKYLIGHT_SESSION_TOKEN"]).to eq("zomg")
      end

      it "includes custom component settings" do
        config[:env] = "staging"
        config[:component] = "worker"
        expect(get_env["SKYLIGHT_AUTHENTICATION"]).to \
          eq("abc123|component=worker%3Astaging&reporting_env=true")
      end

      it "includes custom worker_component settings" do
        config[:worker_component] = "sidekiq"
        expect(get_env["SKYLIGHT_AUTHENTICATION"]).to \
          eq("abc123|component=sidekiq%3Aproduction&reporting_env=true")
      end
    end

    context "legacy settings" do
      it "remaps agent.sockfile_path" do
        c = Config.new(agent: { sockfile_path: "/foo/bar" })
        expect(c[:'agent.sockfile_path']).to eq("/foo/bar")
        expect(c[:'daemon.sockdir_path']).to eq("/foo/bar")

        env = Hash[*c.to_native_env]
        expect(env["SKYLIGHT_AGENT_SOCKFILE_PATH"]).to be_nil
        expect(env["SKYLIGHT_SOCKDIR_PATH"]).to eq("/foo/bar")
      end
    end

    context "serialization" do
      it "includes custom component metadata" do
        config = Config.new(component: "worker", env: "development").as_json

        %i(priority values).each do |subkey|
          expect(config[:config][subkey][:component]).to eq("worker")
          expect(config[:config][subkey][:env]).to eq("development")
        end
      end

      it "includes inferred component metadata in the priority group" do
        config = Config.new.as_json

        expect(config[:config][:priority][:component]).to(
          eq(Skylight::Util::Component::DEFAULT_NAME)
        )

        expect(config[:config][:priority][:env]).to(
          eq(Skylight::Util::Component::DEFAULT_ENVIRONMENT)
        )
      end
    end
  end
end
