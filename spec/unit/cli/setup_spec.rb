require 'spec_helper'

describe 'skylight setup', :http, :agent do

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

  def test_config_values
    @test_config_values ||= begin
      vals = super.dup
      vals.delete(:authentication)
      vals
    end
  end

  def should_successfully_create_app(token=nil)
    server.mock "/apps", :post do
      { app:
        { id: "my-app-id",
          token: "my-app-token" }}
    end

    unless token
      cli.should_receive(:say).
        with(/Please enter your email and password/, :cyan).ordered

      cli.should_receive(:say).
        with(/congratulations/i, :green).ordered

      cli.should_receive(:say).
        with(/config\/skylight\.yml/)
    end

    cli.setup(token)

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

  end

  context 'with token' do

    it 'does not ask for login info' do
      should_successfully_create_app('foobar')

      server.requests[0].should post_json("/apps", {
        authorization: nil,
        input: { 'app' => { 'name' => 'Tmp' }, 'token' => 'foobar' } })
    end

    it 'handles server errors' do
      server.mock "/apps", :post do
        [403, { errors: { request: 'token is invalid' }}]
      end

      cli.should_receive(:say).with("Could not create the application", :red).ordered
      cli.should_receive(:say).with('{"request"=>"token is invalid"}', :yellow).ordered

      cli.setup('foobar')
    end

    it "handles http exceptions" do
      server.mock "/apps", :post do
        raise "http error"
      end

      cli.should_receive(:say).with("Could not create the application", :red).ordered
      cli.should_receive(:say).with("Skylight::Util::HTTP::Response: Fail", :yellow).ordered

      cli.setup('foobar')
    end

  end

end
