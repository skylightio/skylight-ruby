require 'spec_helper'

describe 'skylight setup', :http do

  let(:hl) { double("highline") }

  def cli
    @cli ||=
      begin
        cli = Skylight::CLI.new
        cli.stub(:highline).and_return(hl)
        cli.stub(:config).and_return(config)
        cli
      end
  end

  def should_successfully_create_app
    server.mock "/apps", :post do
      { app:
        { id: "my-app-id",
          token: "my-app-token" }}
    end

    cli.should_receive(:say).
      with(/congratulations/i, :green)

    cli.should_receive(:say).
      with(/config\/skylight\.yml/)

    cli.setup

    tmp('config/skylight.yml').should exist

    c = Skylight::Config.load(tmp('config/skylight.yml'))
    c[:application].should == 'my-app-id'
    c[:authentication].should == 'my-app-token'
  end

  context 'logged out' do

    def should_successfully_login
      hl.should_receive(:ask).
        with(/email/i).and_return('engineering@tilde.io')

      hl.should_receive(:ask).
        with(/password/i).and_return('enter')

      server.mock "/me" do
        { me:
          { authentication_token: "dat-token" }}
      end

      should_successfully_create_app

      tmp('.skylight').should exist

      YAML.load_file(tmp('.skylight')).should == { 'token' => 'dat-token' }
    end

    it 'logs in and creates the app' do
      should_successfully_login

      server.should have(2).requests

      server.requests[0].should get_json("/me", {
        'x-email' => 'engineering@tilde.io',
        'x-password' => 'enter' })

      server.requests[1].should post_json("/apps", {
        input: { 'app' => { 'name' => 'Tmp' }} })
    end

    it 'asks for the login info again if it is incorrect' do
      hl.should_receive(:ask).
        with(/email/i).and_return('zomg')

      hl.should_receive(:ask).
        with(/password/i).and_return('lulz')

      server.mock "/me" do
        [ 401, {} ]
      end

      cli.should_receive(:say).with(/invalid/i, :red)

      should_successfully_login

      server.should have(3).requests

      server.requests[0].should get_json("/me", {
        'x-email' => 'zomg',
        'x-password' => 'lulz' })

      server.requests[1].should get_json("/me", {
        'x-email' => 'engineering@tilde.io',
        'x-password' => 'enter' })

      server.requests[2].should post_json("/apps", {
        authorization: 'dat-token',
        input: { 'app' => { 'name' => 'Tmp' }} })
    end

    it 'handles server errors'

  end

  context 'logged in' do

    it 'does not ask for login info' do
      write_credentials('zomg')

      should_successfully_create_app

      server.requests[0].should post_json("/apps", {
        authorization: 'zomg',
        input: { 'app' => { 'name' => 'Tmp' }} })
    end

  end

  def write_credentials(token)
    File.open(tmp('.skylight'), 'w') do |f|
      f.write YAML.dump('token' => token)
    end
  end

end
