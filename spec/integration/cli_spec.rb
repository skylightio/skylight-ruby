require 'spec_helper'
require 'tmpdir'
require 'open3'

describe "CLI integration", :http do

  # Make sure this is executed before we mess with the env, just in case
  let! :rails_version do
    require 'rails'
    Rails.version
  end

  it "works" do
    server.mock "/me" do |env|
      env['HTTP_X_EMAIL'].should == "test@example.com"
      env['HTTP_X_PASSWORD'].should == "testpass"

      { me: { authentication_token: "testtoken" }}
    end

    server.mock "/apps", :post do |env|
      env['HTTP_AUTHORIZATION'].should == "testtoken"
      env['rack.input'].should == { 'app' => { 'name' => 'Dummy' }}

      # This would have more information really, but the CLI doesn't care
      { app: { id: 'appid', token: 'apptoken' }}
    end

    # This also resets other ENV vars that are set in the block
    Bundler.with_clean_env do
      with_dummy do
        set_env

        IO.popen("bundle install") do |stdout|
          puts stdout.read if ENV['DEBUG']
        end

        Open3.popen3("bundle exec skylight setup") do |stdin, stdout, stderr|
          begin
            get_prompt(stdout).should =~ /Email:\s*$/
            fill_prompt(stdin, "test@example.com")

            get_prompt(stdout).should =~ /Password:\s*$/
            fill_prompt(stdin, "testpass", false)

            read(stdout).should include("Congratulations. Your application is on Skylight!")

            YAML.load_file("../.skylight").should == {"token"=>"testtoken"}

            YAML.load_file("config/skylight.yml").should == {"application"=>"appid", "authentication"=>"apptoken"}
          rescue
            # Provide some potential debugging information
            puts stderr.read if ENV['DEBUG']
            raise
          end
        end
      end
    end
  end

  def with_dummy(&blk)
    Dir.mktmpdir do |dir|
      FileUtils.cp_r File.join(APP_ROOT, "spec/dummy"), dir
      Dir.chdir(File.join(dir, "dummy"), &blk)
    end
  end

  def set_env
    # Gemfile
    ENV['RAILS_VERSION'] = rails_version
    ENV['SKYLIGHT_GEM_PATH'] = APP_ROOT

    # Skylight config
    ENV['SKYLIGHT_ME_CREDENTIALS_PATH'] = File.expand_path("../.skylight")
    ENV['SKYLIGHT_ACCOUNTS_HOST']    = "localhost"
    ENV['SKYLIGHT_ACCOUNTS_PORT']    = port.to_s
    ENV['SKYLIGHT_ACCOUNTS_SSL']     = "false"
    ENV['SKYLIGHT_ACCOUNTS_DEFLATE'] = "false"
  end

  def get_prompt(io, limit=100)
    prompt = io.readpartial(limit)
    print prompt if ENV['DEBUG']
    prompt
  end

  def fill_prompt(io, str, echo=ENV['DEBUG'])
    io.puts str
    puts str if echo
  end

  def read(io)
    result = io.read
    puts result if ENV['DEBUG']
    result
  end

end