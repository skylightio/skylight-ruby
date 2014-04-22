require 'spec_helper'
require 'tmpdir'

describe "Initialization integration" do

  let(:rails_env) { "development" }

  before :all do
    @tmpdir = Dir.mktmpdir
    with_standalone(dir: @tmpdir) do
      output = `bundle install`
      puts output if ENV['DEBUG']
    end
  end

  after :all do
    FileUtils.remove_entry_secure @tmpdir
  end

  around :each do |example|
    # Any ENV vars set inside of with_clean_env will be reset
    with_standalone(dir: @tmpdir) do
      ENV['SKYLIGHT_AUTHENTICATION'] = 'lulz'
      ENV['SKYLIGHT_AGENT_STRATEGY'] = 'embedded'
      ENV['SKYLIGHT_LOG_FILE'] = '-'
      example.run
    end
  end

  def boot
    `RAILS_ENV=#{rails_env} rails runner '#noop'`.strip
  end

  if Skylight.native?

    context "native" do

      context "development" do

        it "warns development mode" do
          boot.should == "[SKYLIGHT] [#{Skylight::VERSION}] Running Skylight in development mode. No data will be reported until you deploy your app."
        end

      end

      context "test" do
        let(:rails_env) { "test" }

        it "doesn't boot or warn" do
          boot.should == ""
        end

      end

      context "production" do
        let(:rails_env) { "production" }

        it "notifies of boot" do
          boot.should =~ /\[SKYLIGHT\] \[#{Skylight::VERSION}\] Skylight agent enabled/
        end
      end

      context "custom enabled environment (staging)" do
        let(:rails_env) { "staging" }

        it "notifies of boot" do
          boot.should =~ /\[SKYLIGHT\] \[#{Skylight::VERSION}\] Skylight agent enabled/
       end
      end

      context "custom disabled environment (other)" do
        let(:rails_env) { "other" }

        it "warns that it is disabled" do
          boot.should == "[SKYLIGHT] [#{Skylight::VERSION}] You are running in the other environment but haven't added it to config.skylight.environments, so no data will be sent to skylight.io."
        end

      end

    end

  end

  context "without native" do

    before :each do
      ENV['SKYLIGHT_DISABLE_AGENT'] = 'true'
    end

    context "development" do

      it "warns development mode" do
        boot.should == "[SKYLIGHT] [#{Skylight::VERSION}] Running Skylight in development mode. No data will be reported until you deploy your app."
      end

    end

    context "test" do
      let(:rails_env) { "test" }

      it "doesn't boot or warn" do
        boot.should == ""
      end

    end

    context "production" do
      let(:rails_env) { "production" }

      it "warns not enabled verbose" do
        boot.should == "[SKYLIGHT] [#{Skylight::VERSION}] The Skylight native extension for your platform wasn't found. The monitoring portion of Skylight is only supported on production servers running 32- or 64-bit Linux. The missing extension will not affect the functioning of your application and you can continue local development without data being reported. If you are on a supported platform, please contact support at support@skylight.io."
      end

    end

    context "custom enabled environment (staging)" do
      let(:rails_env) { "staging" }

      it "warns not enabled verbose" do
        boot.should == "[SKYLIGHT] [#{Skylight::VERSION}] The Skylight native extension for your platform wasn't found. The monitoring portion of Skylight is only supported on production servers running 32- or 64-bit Linux. The missing extension will not affect the functioning of your application and you can continue local development without data being reported. If you are on a supported platform, please contact support at support@skylight.io."      end

    end

    context "custom disabled environment (other)" do
      let(:rails_env) { "other" }

      it "warns that it is disabled" do
        boot.should == "[SKYLIGHT] [#{Skylight::VERSION}] You are running in the other environment but haven't added it to config.skylight.environments, so no data will be sent to skylight.io."
      end

    end

  end

end
