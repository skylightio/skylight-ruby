require "spec_helper"
require "tmpdir"
require "fileutils"

describe "Initialization integration", :http do
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

  before :each do
    @expect_success = true
    stub_config_validation

    # Make sure logs don't persist between tests
    Dir["#{@tmpdir}/dummy/log/*"].each { |l| FileUtils.rm(l) }
  end

  before :each, expect_success: false do
    @expect_success = false
  end

  around :each do |example|
    # Any ENV vars set inside of with_unbundled_env will be reset
    with_standalone(dir: @tmpdir) do
      user_config_path = "#{@tmpdir}/skylight_user_config.yml"
      ENV["SKYLIGHT_AUTHENTICATION"] = "lulz"
      ENV["SKYLIGHT_AGENT_STRATEGY"] = "embedded"
      ENV["SKYLIGHT_USER_CONFIG_PATH"] = user_config_path
      example.run
      FileUtils.rm_f user_config_path
    end
  end

  def boot(debug: true)
    pipe_cmd_in, pipe_cmd_out = IO.pipe

    # Reset logs
    FileUtils.rm_rf "log"
    FileUtils.mkdir "log"

    original_trace = ENV.fetch("SKYLIGHT_ENABLE_TRACE_LOGS", nil)
    ENV.delete("SKYLIGHT_ENABLE_TRACE_LOGS")

    env = { "RAILS_ENV" => rails_env }
    if debug
      env["SKYLIGHT_ENABLE_TRACE_LOGS"] = "1"
      env["DEBUG"] = "1"
    end
    cmd = "ruby bin/rails runner 'exit(1) if Skylight.native? && !Skylight.started?'"
    cmd_pid = Process.spawn(env, cmd, out: pipe_cmd_out, err: pipe_cmd_out)

    ENV["SKYLIGHT_ENABLE_TRACE_LOGS"] = original_trace

    Timeout.timeout(10) { Process.wait(cmd_pid) }

    pipe_cmd_out.close

    output = pipe_cmd_in.read.strip.split("\n")

    Kernel.warn(output) unless $CHILD_STATUS.success? == @expect_success

    expect($CHILD_STATUS.success?).to eq(@expect_success)

    # Rails 4 has a deprecation under Ruby 2.6 which isn't likely to be fixed and isn't our fault.
    output.reject! { |l| l =~ /BigDecimal.new is deprecated/ } if Rails::VERSION::MAJOR == 4

    # This deprecation is not our fault
    output.reject! { |l| l.include?("Rack::File is deprecated") }

    _, i = output.to_enum.with_index.find do |l, _|
      # In rails 7.1, This is both a default value set on ActiveSupport::Cache, and is deprecated
      # (requires a positive opt-in for the newer version). It's better for us not to set it
      # to anything other than the default, so we can just ignore this multi-line deprecation warning.
      l.include?("Support for `config.active_support.cache_format_version = 6.1") ||
        l.include?("upgrading_ruby_on_rails.html#new-activesupport-cache-serialization-format")
    end

    if i
      a, b, c, d, e = output.slice!(i, 5)

      matches_expected =
        a.include?("Support for `config.active_support.cache_format_version = 6.1") &&
        b == "" &&
        c =~ /Check the Rails upgrade guide/ &&
        d =~ /for more information on how to upgrade/ &&
        e =~ /\(called from <top \(required\)> at/

      unless matches_expected
        raise "unexpected output removed: #{matches_expected.inspect} #{[a, b, c, d, e].inspect}"
      end
    end

    # Ruby 2.7 has deprecated some keyword behaviors
    if RUBY_VERSION =~ /^2\.7/
      filtered_output = []
      keyword_warning = false
      output.each do |l|
        if l.include?("warning: Using the last argument as keyword parameters is deprecated")
          keyword_warning = true
        elsif keyword_warning && l.include?("warning: The called method")
          # Ignore
        else
          keyword_warning = false
          filtered_output << l
        end
      end
      output = filtered_output
    end

    %w[logger ostruct].each do |lib|
      (_, i), = output.to_enum.with_index.each_cons(2).find do |(l0, _i0), (l1, _i1)|
        l0 =~ /#{lib} was loaded from the standard library/ &&
        l1 =~ /You can add #{lib} to your Gemfile or gemspec to silence this warning./
      end

      output.slice!(i, 2) if i
    end

    output.reject! do |line| 
      line =~ /DEPRECATION WARNING: `to_time` will always preserve the receiver timezone rather than system local time in Rails 8.0/
    end

    output.join("\n")
  rescue Timeout::Error
    Process.kill("TERM", cmd_pid)
    raise
  end

  if Skylight.native?
    context "native" do
      context "development", expect_success: false do
        it "warns development mode" do
          expect(boot).to include "[SKYLIGHT] [#{Skylight::VERSION}] Running Skylight in development mode. No data " \
                    "will be reported until you deploy your app."
        end

        # FIXME: This is a very fragile test, due to the "to_not"
        it "doesn't warn about validation errors" do
          ENV["SKYLIGHT_AUTHENTICATION"] = nil

          boot

          expect(File.read("log/development.log")).to_not include "[SKYLIGHT] [#{Skylight::VERSION}] Unable to " \
                    "start, see the Skylight logs for more details"
          expect(File.read("log/skylight.log")).to_not include "Skylight: Unable to start Instrumenter due to a " \
                    "configuration error: authentication token required"
        end

        it "doesn't warn in development mode if disable_dev_warning has been set" do
          # `bundle exec skylight disable_dev_warning`
          out = capture(:stdout) { Skylight::CLI::Base.new.disable_dev_warning }

          expect(out.strip).to eq("Development mode warning disabled")

          expect(boot).to_not include "development mode"
        end
      end

      context "test", expect_success: false do
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

        it "warns about validation errors", expect_success: false do
          ENV["SKYLIGHT_AUTHENTICATION"] = nil

          boot
          expect(File.read("log/production.log")).to include "[SKYLIGHT] [#{Skylight::VERSION}] Unable to start, " \
                    "see the Skylight logs for more details"
          expect(File.read("log/skylight.log")).to include "Skylight: Unable to start Instrumenter due to a " \
                    "configuration error: authentication token required"
        end
      end

      context "custom enabled environment (staging)" do
        let(:rails_env) { "staging" }

        it "notifies of boot" do
          boot
          expect(File.read("log/staging.log")).to include "[SKYLIGHT] [#{Skylight::VERSION}] Skylight agent enabled"
        end
      end

      context "custom disabled environment (other)", expect_success: false do
        let(:rails_env) { "other" }

        it "warns that it is disabled" do
          expect(boot).to include "[SKYLIGHT] [#{Skylight::VERSION}] You are running in the other environment but " \
                    "haven't added it to config.skylight.environments, so no data will be sent to " \
                    "Skylight servers."
        end
      end

      context "invalid environment name", expect_success: false do
        let(:rails_env) { "production" }

        it "warns that it is disabled" do
          ENV["SKYLIGHT_ENV"] = "oh no!"
          boot

          log_lines = File.read("log/production.log").lines + File.read("log/skylight.log").lines
          expect(log_lines).to include(
            a_string_matching(/environment can only contain lowercase letters, numbers, and dashes;/)
          )
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
        expect(boot).to include "[SKYLIGHT] [#{Skylight::VERSION}] Running Skylight in development mode. No data " \
                  "will be reported until you deploy your app."
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
        expect(boot).to include "[SKYLIGHT] [#{Skylight::VERSION}] The Skylight native extension for your " \
                  "platform wasn't found. Supported operating systems are Linux 2.6.18+ and " \
                  "Mac OS X 10.8+. The missing extension will not affect the functioning of your " \
                  "application. If you are on a supported platform, please contact support at " \
                  "support@skylight.io."
      end
    end

    context "custom enabled environment (staging)" do
      let(:rails_env) { "staging" }

      it "warns not enabled verbose" do
        expect(boot).to include "[SKYLIGHT] [#{Skylight::VERSION}] The Skylight native extension for your " \
                  "platform wasn't found. Supported operating systems are Linux 2.6.18+ and " \
                  "Mac OS X 10.8+. The missing extension will not affect the functioning of your " \
                  "application. If you are on a supported platform, please contact support at " \
                  "support@skylight.io."
      end
    end

    context "custom disabled environment (other)" do
      let(:rails_env) { "other" }

      it "warns that it is disabled" do
        expect(boot).to include "[SKYLIGHT] [#{Skylight::VERSION}] You are running in the other environment but " \
                  "haven't added it to config.skylight.environments, so no data will be sent to " \
                  "Skylight servers."
      end
    end
  end
end
