require "spec_helper"

describe "skylight setup", :http, :agent do
  let(:hl) { double("highline") }

  def cli
    @cli ||=
      begin
        cli = Skylight::CLI::Base.new
        allow(cli).to receive(:highline).and_return(hl)
        allow(cli).to receive(:config).and_return(config)
        cli
      end
  end

  def test_config_values
    @test_config_values ||=
      begin
        vals = super.dup
        vals.delete(:authentication)
        vals
      end
  end

  def should_successfully_create_app(token = nil)
    server.mock "/apps", :post do
      { app: { id: "my-app-id", token: "my-app-token" } }
    end

    unless token
      expect(cli).to receive(:say).with(/Please enter your email and password/, :cyan).ordered

      expect(cli).to receive(:say).with(/congratulations/i, :green).ordered

      expect(cli).to receive(:say).with(%r{config/skylight\.yml})
    end

    capture(:stdout) { cli.setup(token) }

    expect(tmp("config/skylight.yml")).to exist

    c = Skylight::Config.load(file: tmp("config/skylight.yml"))
    expect(c[:authentication]).to eq("my-app-token")
  end

  context "within a Rails app" do
    let!(:namefile) { Tempfile.new }

    before do
      allow(Tempfile).to receive(:new).with("skylight-app-name") { namefile }
      allow(namefile).to receive(:read) { "MyCoolRailsApp::Application" }

      # The existence of this file is how we determine whether
      # we're running within a Rails app.
      tmp("config/application.rb").tap do |file|
        FileUtils.mkdir_p(file.dirname)
        FileUtils.touch(file)
      end
    end

    it "infers the app name from Rails" do
      should_successfully_create_app("foobar")

      expect(server.requests[0]).to post_json(
        "/apps",
        hash_including(input: hash_including(app: { name: "My Cool Rails App" }))
      )
    end
  end

  context "with token" do
    it "does not ask for login info" do
      should_successfully_create_app("foobar")

      # Name "Spec" comes from the default file location of tmp/spec
      expect(server.requests[0]).to post_json(
        "/apps",
        authorization: nil,
        input: {
          "app" => {
            "name" => "Spec"
          },
          "token" => "foobar"
        }
      )
    end

    it "handles server errors" do
      server.mock "/apps", :post do
        [403, { errors: { request: "token is invalid" } }]
      end

      expect(cli).to receive(:say)
        .with(
          "Could not create the application. Please run `bundle exec skylight doctor` " \
            "for diagnostics.",
          :red
        )
        .ordered
      expect(cli).to receive(:say).with("{\"request\"=>\"token is invalid\"}", :yellow).ordered

      cli.setup("foobar")
    end

    it "handles http exceptions" do
      server.mock "/apps", :post do
        raise "http error"
      end

      expect(cli).to receive(:say)
        .with(
          "Could not create the application. Please run `bundle exec skylight doctor` " \
            "for diagnostics.",
          :red
        )
        .ordered
      expect(cli).to receive(:say).with("Skylight::Util::HTTP::Response: Fail", :yellow).ordered

      cli.setup("foobar")
    end
  end
end
