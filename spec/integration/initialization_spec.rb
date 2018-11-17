require "spec_helper"
require "tmpdir"
require "fileutils"

describe "Initialization integration" do
  let(:rails_env) { "development" }

  before :all do
    @tmpdir = Dir.mktmpdir
    with_standalone(dir: @tmpdir) do
      output = `bundle install`
      puts output if ENV["DEBUG"]
    end
  end

  after :all do
    FileUtils.remove_entry_secure @tmpdir
  end

  around :each do |example|
    # Any ENV vars set inside of with_clean_env will be reset
    with_standalone(dir: @tmpdir) do
      user_config_path = "#{@tmpdir}/skylight_user_config.yml"
      ENV["SKYLIGHT_AUTHENTICATION"] = "lulz"
      ENV["SKYLIGHT_AGENT_STRATEGY"] = "embedded"
      ENV["SKYLIGHT_USER_CONFIG_PATH"] = user_config_path
      example.run
      FileUtils.rm_f user_config_path
    end
  end

  # FIXME: Sometimes this can hang for no apparent reason
  def boot(debug: true)
    pipe_cmd_in, pipe_cmd_out = IO.pipe

    # Reset logs
    FileUtils.rm_rf "log"
    FileUtils.mkdir "log"

    original_trace = ENV["SKYLIGHT_ENABLE_TRACE_LOGS"]
    ENV.delete("SKYLIGHT_ENABLE_TRACE_LOGS")

    env = { "RAILS_ENV" => rails_env }
    env.merge!("SKYLIGHT_ENABLE_TRACE_LOGS" => "1", "DEBUG" => "1") if debug
    cmd = "ruby bin/rails runner '#noop'"
    cmd_pid = Process.spawn(env, cmd, :out => pipe_cmd_out, :err => pipe_cmd_out)

    ENV["SKYLIGHT_ENABLE_TRACE_LOGS"] = original_trace

    Timeout.timeout(10) do
      Process.wait(cmd_pid)
    end

    pipe_cmd_out.close
    pipe_cmd_in.read.strip
  rescue Timeout::Error
    Process.kill("TERM", cmd_pid)
    raise
  end

  if Skylight.native?

    context "native" do
      context "development" do
        it "warns development mode" do
          expect(boot).to include "[SKYLIGHT] [#{Skylight::VERSION}] Running Skylight in development mode. No data will be reported until you deploy your app."
        end

        # FIXME: This is a very fragile test, due to the "to_not"
        it "doesn't warn about validation errors" do
          ENV["SKYLIGHT_AUTHENTICATION"] = nil

          boot

          expect(File.read("log/development.log")).to_not include "[SKYLIGHT] [#{Skylight::VERSION}] Unable to start, see the Skylight logs for more details"
          expect(File.read("log/skylight.log")).to_not include "Skylight: Unable to start Instrumenter due to a configuration error: authentication token required"
        end

        it "doesn't warn in development mode if disable_dev_warning has been set" do
          # `bundle exec skylight disable_dev_warning`
          out = capture(:stdout) do
            Skylight::CLI::Base.new.disable_dev_warning
          end

          expect(out.strip).to eq("Development mode warning disabled")

          expect(boot).to_not include "development mode"
        end
      end

      context "test" do
        let(:rails_env) { "test" }

        it "doesn't boot or warn" do
          expect(boot(debug: false)).to eq("")
        end
      end

      context "production" do
        let(:rails_env) { "production" }

        it "notifies of boot" do
          boot
          expect(File.read("log/production.log")).to include "[SKYLIGHT] [#{Skylight::VERSION}] Skylight agent enabled"
        end

        it "warns about validation errors" do
          ENV["SKYLIGHT_AUTHENTICATION"] = nil

          boot
          expect(File.read("log/production.log")).to include "[SKYLIGHT] [#{Skylight::VERSION}] Unable to start, see the Skylight logs for more details"
          expect(File.read("log/skylight.log")).to include "Skylight: Unable to start Instrumenter due to a configuration error: authentication token required"
        end
      end

      context "custom enabled environment (staging)" do
        let(:rails_env) { "staging" }

        it "notifies of boot" do
          boot
          expect(File.read("log/staging.log")).to include "[SKYLIGHT] [#{Skylight::VERSION}] Skylight agent enabled"
        end
      end

      context "custom disabled environment (other)" do
        let(:rails_env) { "other" }

        it "warns that it is disabled" do
          expect(boot).to include "[SKYLIGHT] [#{Skylight::VERSION}] You are running in the other environment but haven't added it to config.skylight.environments, so no data will be sent to Skylight servers."
        end
      end
    end

  end

  context "without native" do
    before :each do
      ENV["SKYLIGHT_DISABLE_AGENT"] = "true"
    end

    context "development" do
      it "warns development mode" do
        expect(boot).to include "[SKYLIGHT] [#{Skylight::VERSION}] Running Skylight in development mode. No data will be reported until you deploy your app."
      end
    end

    context "test" do
      let(:rails_env) { "test" }

      it "doesn't boot or warn" do
        expect(boot(debug: false)).to eq("")
      end
    end

    context "production" do
      let(:rails_env) { "production" }

      it "warns not enabled verbose" do
        expect(boot).to include "[SKYLIGHT] [#{Skylight::VERSION}] The Skylight native extension for your platform wasn't found. Supported operating systems are Linux 2.6.18+ and Mac OS X 10.8+. The missing extension will not affect the functioning of your application. If you are on a supported platform, please contact support at support@skylight.io."
      end
    end

    context "custom enabled environment (staging)" do
      let(:rails_env) { "staging" }

      it "warns not enabled verbose" do
        expect(boot).to include "[SKYLIGHT] [#{Skylight::VERSION}] The Skylight native extension for your platform wasn't found. Supported operating systems are Linux 2.6.18+ and Mac OS X 10.8+. The missing extension will not affect the functioning of your application. If you are on a supported platform, please contact support at support@skylight.io."
      end
    end

    context "custom disabled environment (other)" do
      let(:rails_env) { "other" }

      it "warns that it is disabled" do
        expect(boot).to include "[SKYLIGHT] [#{Skylight::VERSION}] You are running in the other environment but haven't added it to config.skylight.environments, so no data will be sent to Skylight servers."
      end
    end
  end
end
