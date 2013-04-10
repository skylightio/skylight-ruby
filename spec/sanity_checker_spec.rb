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

        problems = SanityChecker.new(app, Config.new).sanity_check
        problems["skylight.yml"].should include("does not exist")
      end

      it "should report a problem if skylight.yml doesn't contain an app ID" do
        problems = SanityChecker.new(app, Config.new).sanity_check
        problems["skylight.yml"].should include("does not contain an app id - please run `skylight create`")
      end

      it "should not report a problem if skylight.yml contains an app ID" do
        File.write(yaml, YAML.dump({ "app_id" => "helloworld" }))

        problems = SanityChecker.new(app, Config.new(app_id: "helloworld")).sanity_check
        problems["skylight.yml"].should_not include("does not contain an app id - please run `skylight create`")
      end

      it "should report a problem if skylight.yml doesn't contain an app token" do
        problems = SanityChecker.new(app, Config.new).sanity_check
        problems["skylight.yml"].should include("does not contain an app token - please run `skylight create`")
      end

      it "should not report a problem if skylight.yml contains an app token" do
        problems = SanityChecker.new(app, Config.new(authentication_token: "helloworld")).sanity_check
        problems["skylight.yml"].should_not include("does not contain an app token - please run `skylight create`")
      end
    end
  end
end
