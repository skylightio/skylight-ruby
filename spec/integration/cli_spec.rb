require 'spec_helper'
require 'open3'

describe "CLI integration", :http do

  it "works with setup token" do
    server.mock "/apps", :post do |env|
      env['rack.input'].should == { 'app' => { 'name' => 'Dummy' }, 'token' => 'setuptoken' }

      # This would have more information really, but the CLI doesn't care
      { app: { id: 'appid', token: 'apptoken' }}
    end

    with_standalone do
      output = `bundle install`
      puts output if ENV['DEBUG']

      Open3.popen3("bundle exec skylight setup setuptoken") do |stdin, stdout, stderr|
        begin
          read(stdout).should include("Congratulations. Your application is on Skylight!")

          YAML.load_file("config/skylight.yml").should == {"application"=>"appid", "authentication"=>"apptoken"}
        rescue
          # Provide some potential debugging information
          puts stderr.read if ENV['DEBUG']
          raise
        end
      end
    end
  end

  it "shows error messages for invalid token" do
    server.mock "/apps", :post do |env|
      env['rack.input'].should == { 'app' => { 'name' => 'Dummy' }, 'token' => 'invalidtoken' }
      [403, { errors: { request: "invalid app create token" }}]
    end

    with_standalone do
      output = `bundle install`
      puts output if ENV['DEBUG']

      Open3.popen3("bundle exec skylight setup invalidtoken") do |stdin, stdout, stderr|
        begin
          output = read(stdout)
          output.should include("Could not create the application")
          output.should include('{"request"=>"invalid app create token"}')

          File.exist?("config/skylight.yml").should be_falsey
        rescue
          # Provide some potential debugging information
          puts stderr.read if ENV['DEBUG']
          raise
        end
      end
    end
  end

  it "works without setup token" do
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

    with_standalone do
      output = `bundle install`
      puts output if ENV['DEBUG']

      Open3.popen3("bundle exec skylight setup") do |stdin, stdout, stderr|
        begin
          get_prompt(stdout, 200).should =~ %r{Please enter your email and password below or get a token from https://www.skylight.io/app/setup.}
          get_prompt(stdout).should =~ /Email:\s*$/
          fill_prompt(stdin, "test@example.com")

          get_prompt(stdout).should =~ /Password:\s*$/
          fill_prompt(stdin, "testpass", false)

          read(stdout).should include("Congratulations. Your application is on Skylight!")

          YAML.load_file("config/skylight.yml").should == {"application"=>"appid", "authentication"=>"apptoken"}
        rescue
          # Provide some potential debugging information
          puts stderr.read if ENV['DEBUG']
          raise
        end
      end
    end
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
