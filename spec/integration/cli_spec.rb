require 'spec_helper'
require 'open3'

describe "CLI integration", :http do

  def run_command(cmd, &block)
    Open3.popen3({ "RUBYLIB" => $native_lib_path }, "bundle exec skylight #{cmd}", &block)
  end

  it "works with setup token" do
    server.mock "/apps", :post do |env|
      expect(env['rack.input']).to eq({ 'app' => { 'name' => 'Dummy' }, 'token' => 'setuptoken' })

      # This would have more information really, but the CLI doesn't care
      { app: { id: 'appid', token: 'apptoken' }}
    end

    with_standalone do
      output = `bundle install`
      puts output if ENV['DEBUG']

      run_command("setup setuptoken") do |stdin, stdout, stderr|
        begin
          expect(read(stdout)).to include("Congratulations. Your application is on Skylight!")

          expect(YAML.load_file("config/skylight.yml")).to eq({"authentication"=>"apptoken"})
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
      expect(env['rack.input']).to eq({ 'app' => { 'name' => 'Dummy' }, 'token' => 'invalidtoken' })
      [403, { errors: { request: "invalid app create token" }}]
    end

    with_standalone do
      output = `bundle install`
      puts output if ENV['DEBUG']

      run_command("setup invalidtoken") do |stdin, stdout, stderr|
        begin
          output = read(stdout)
          expect(output).to include("Could not create the application")
          expect(output).to include('{"request"=>"invalid app create token"}')

          expect(File.exist?("config/skylight.yml")).to be_falsey
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
      expect(env['HTTP_X_EMAIL']).to eq("test@example.com")
      expect(env['HTTP_X_PASSWORD']).to eq("testpass")

      { me: { authentication_token: "testtoken" }}
    end

    server.mock "/apps", :post do |env|
      expect(env['HTTP_AUTHORIZATION']).to eq("testtoken")
      expect(env['rack.input']).to eq({ 'app' => { 'name' => 'Dummy' }})

      # This would have more information really, but the CLI doesn't care
      { app: { id: 'appid', token: 'apptoken' }}
    end

    with_standalone do
      output = `bundle install`
      puts output if ENV['DEBUG']

      run_command("setup") do |stdin, stdout, stderr|
        begin
          expect(get_prompt(stdout, 200)).to match(%r{Please enter your email and password below or get a token from https://www.skylight.io/app/setup.})
          expect(get_prompt(stdout)).to match(/Email:\s*$/)
          fill_prompt(stdin, "test@example.com")

          expect(get_prompt(stdout)).to match(/Password:\s*$/)
          fill_prompt(stdin, "testpass", false)

          expect(read(stdout)).to include("Congratulations. Your application is on Skylight!")

          expect(YAML.load_file("config/skylight.yml")).to eq({"authentication"=>"apptoken"})
        rescue
          # Provide some potential debugging information
          puts stderr.read if ENV['DEBUG']
          raise
        end
      end
    end
  end

  it "shows notice if config/skylight.yml already exists" do
    with_standalone do
      output = `bundle install`
      puts output if ENV['DEBUG']

      system("touch config/skylight.yml")

      run_command("setup token") do |stdin, stdout, stderr|
        begin
          expect(read(stdout)).to match(%r{A config/skylight.yml already exists for your application.})
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
