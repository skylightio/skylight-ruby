require "spec_helper"
require "fileutils"

module Skylight
  describe SanityChecker do
    let(:dummy) { File.expand_path("../dummy", __FILE__) }
    let(:app) { File.expand_path("../dummy-broken", __FILE__) }
    let(:yaml) { File.join(app, "config/skylight.yml") }

    before do
      FileUtils.cp_r(dummy, app)
    end

    after do
      FileUtils.rm_rf(app)
    end

    describe "skylight.yml" do
      it "should report a problem if skylight.yml doesn't exist" do
        FileUtils.rm(yaml)

        problems = SanityChecker.new.smoke_test(yaml)
        problems["skylight.yml"].should include("does not exist")
      end

      it "should report a problem if skylight.yml doesn't contain an app ID" do
        problems = SanityChecker.new.sanity_check(Config.new)
        problems["skylight.yml"].should include("does not contain an app id - please run `skylight create`")
      end

      it "should report a problem if skylight.yml doesn't contain an app token" do
        problems = SanityChecker.new.sanity_check(Config.new("app_id" => "helloworld"))
        problems["skylight.yml"].should include("does not contain an app token - please run `skylight create`")
      end

      it "should not report a problem if skylight.yml contains an app token" do
        problems = SanityChecker.new.sanity_check(Config.new(app_id: "123", authentication_token: "helloworld"))
        problems.should be_nil
      end
    end

    describe "~/.skylight" do
      let(:file) do
        mock("File").tap { |file| file.should_receive(:expand_path).with('~/.skylight').and_return("/path/to/skylight") }
      end

      it "should not report a problem if ~/.skylight exists" do
        file.should_receive(:exist?).with("/path/to/skylight").and_return(true)

        problems = SanityChecker.new(file).user_credentials('~/.skylight')
        problems.should be_nil
      end

      it "should report a problem if ~/.skylight doesn't exist" do
        file.should_receive(:exist?).with("/path/to/skylight").and_return(false)

        problems = SanityChecker.new(file).user_credentials('~/.skylight')
        problems['~/.skylight'].should include("does not exist")
      end
    end
  end
end
