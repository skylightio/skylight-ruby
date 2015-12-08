require 'spec_helper'

module Skylight
  describe Config do

    context 'basic lookup' do

      let :config do
        Config.new :foo => 'hello', 'bar' => 'omg'
      end

      it 'looks keys up with strings' do
        config['foo'].should == 'hello'
        config['bar'].should == 'omg'
      end

      it 'looks keys up with symbols' do
        config[:foo].should == 'hello'
        config[:bar].should == 'omg'
      end

    end

    context '1 level nested lookup' do

      let :config do
        Config.new :one => {
          :foo => 'hello', 'bar' => 'omg' }
      end

      it 'looks keys up with strings' do
        config['one.foo'].should == 'hello'
        config['one.bar'].should == 'omg'
      end

      it 'looks keys up with symbols' do
        config[:'one.foo'].should == 'hello'
        config[:'one.bar'].should == 'omg'
      end

    end

    context '2 level nested lookup' do

      let :config do
        Config.new :one => {
          :two => {
            :foo => 'hello', 'bar' => 'omg' }}
      end

      it 'looks keys up with strings' do
        config['one.two.foo'].should == 'hello'
        config['one.two.bar'].should == 'omg'
      end

      it 'looks keys up with symbols' do
        config[:'one.two.foo'].should == 'hello'
        config[:'one.two.bar'].should == 'omg'
      end

    end

    context 'lookup with defaults' do

      let :config do
        Config.new foo: 'bar'
      end

      context 'with a value' do

        it 'returns the value if key is present' do
          config['foo', 'missing'].should == 'bar'
        end

        it 'returns the default if key is missing' do
          config['bar', 'missing'].should == 'missing'
        end

      end

      context 'with a block' do

        it 'returns the value if key is present' do
          config.get('foo') { 'missing' }.should == 'bar'
        end

        it 'calls the block if key is missing' do
          config.get('bar') { 'missing' }.should == 'missing'
        end

      end

    end

    context 'environment scopes' do

      let :config do
        Config.new('production',
          foo:    'bar',
          one:    1,
          zomg:   'YAY',
          nested: { 'wat' => 'w0t', 'yes' => 'no' },
          production: {
            foo:    'baz',
            two:    2,
            zomg:   nil,
            nested: { 'yes' => 'YES' }
          },
          staging: {
            foo:  'no',
            three: 3 })
      end

      it 'prioritizes the environment config over the default' do
        config[:foo].should == 'baz'
        config[:two].should == 2
      end

      it 'merges nested values' do
        config['nested.wat'].should == 'w0t'
        config['nested.yes'].should == 'YES'
      end

      it 'still can access root values' do
        config[:one].should == 1
      end

      it 'allows nil keys to override defaults' do
        config[:zomg].should be_nil
      end

      it 'can access the environment configs explicitly' do
        config['production.foo'].should == 'baz'
      end

      it 'can still access other environment configs explicitly' do
        config['staging.foo'].should == 'no'
      end

    end

    context 'priority keys' do

      let :config do
        Config.new(
          'production',
          foo: 'bar',
          nested: { foo: 'bar', 'baz' => 'zomg' },
          production: {
            foo: 'baz' },
          priority: {
            foo: 'win',
            one: '1',
            'nested.foo' => 'p' }
                            )
      end

      it 'is available as a top level key' do
        config[:one].should  == '1'
        config['one'].should == '1'
      end

      it 'takes priority over default values and environment scoped values' do
        config[:foo].should == 'win'
      end

      it 'merges nested keys' do
        config['nested.foo'].should == 'p'
        config['nested.baz'].should == 'zomg'
      end

    end

    context 'defaults' do

      it 'uses defaults' do
        config = Config.new
        config['daemon.lazy_start'].should be_truthy
      end

      it 'uses values over defaults' do
        config = Config.new daemon: { lazy_start: false }
        config['daemon.lazy_start'].should be_falsey
      end

      it 'uses nil values over defaults' do
        config = Config.new daemon: { lazy_start: nil }
        config['daemon.lazy_start'].should be_nil
      end

    end

    context 'hostname' do

      it 'defaults to the current hostname' do
        config = Config.new
        config[:hostname].should == Socket.gethostname
      end

      it 'can be overridden' do
        config = Config.new hostname: 'lulz'
        config[:hostname].should == 'lulz'
      end

    end

    context 'duration' do

      it 'assumes durations are seconds' do
        c = Config.new foo: "123"
        c.duration_ms(:foo).should == 123_000
      end

      it 'parses explicit second units' do
        c = Config.new foo: "123sec"
        c.duration_ms(:foo).should == 123_000
      end

      it 'parses ms' do
        c = Config.new foo: "123ms"
        c.duration_ms(:foo).should == 123
      end

      it 'returns nil if there is no value' do
        c = Config.new
        c.duration_ms(:foo).should be_nil
      end

    end

    context 'loading from YAML' do

      let :file do
        tmp('skylight.yml')
      end

      let :config do
        Config.load({file: file, environment: 'production'}, {
          'foo'                     => 'fail',
          'SKYLIGHT_AUTHENTICATION' => 'my-token',
          'SKYLIGHT_APPLICATION'    => 'my-app'})
      end

      context 'valid' do

        before :each do
          file.write <<-YML
  authentication: nope
  zomg: hello
  foo: bar
  stuff: nope
  report:
    ssl: true

  production:
    stuff: waaa

  erb: <%= 'interpolated' %>
          YML
        end

        it 'sets the configuration' do
          config['zomg'].should == 'hello'
        end

        it 'can load the token from an environment variable' do
          config['authentication'].should == 'my-token'
        end

        it 'ignores unknown env keys' do
          config['foo'].should == 'bar'
        end

        it 'loads nested config variables' do
          config['daemon.lazy_start'].should == true
        end

        it 'still overrides' do
          config['stuff'].should == 'waaa'
        end

        it 'interpolates ERB' do
          config['erb'].should == 'interpolated'
        end

      end

      context 'invalid' do

        it 'has useable error for empty files' do
          file.write ''
          lambda{ config }.should raise_error(ConfigError, "could not load config file; msg=empty file")
        end

        it 'has useable error for files with only newlines' do
          file.write "\n"
          lambda{ config }.should raise_error(ConfigError, "could not load config file; msg=empty file")
        end

        it 'has useable error for files with arrays' do
          file.write "- foo\n- bar"
          lambda{ config }.should raise_error(ConfigError, "could not load config file; msg=invalid format")
        end

      end

    end

    context 'legacy ENV key prefix' do

      let :file do
        tmp('skylight.yml')
      end

      before :each do
        file.write <<-YML
  authentication: nope
        YML
      end

      let :config do
        Config.load({file: file, environment: 'production'}, {
          'foo'               => 'fail',
          'SK_AUTHENTICATION' => 'my-token',
          'SK_APPLICATION'    => 'my-app'})
      end

      it 'loads the authentication key' do
        config[:'authentication'].should == 'my-token'
      end

    end

    context "validations" do

      let :config do
        Config.new(authentication: "testtoken")
      end

      it "is valid" do
        lambda { config.validate! }.should_not raise_error
      end

      Config::REQUIRED.each do |key, name|
        it "requires #{key}" do
          config[key] = nil
          lambda { config.validate! }.should raise_error(ConfigError, "#{name} required")
        end
      end

      it "does not allow agent.interval to be a non-zero integer" do
        lambda {
          config['agent.interval'] = "abc"
        }.should raise_error(ConfigError, "invalid value for agent.interval (abc), must be an integer greater than 0")

        lambda {
          config['agent.interval'] = -1
        }.should raise_error(ConfigError, "invalid value for agent.interval (-1), must be an integer greater than 0")

        lambda {
          config['agent.interval'] = 5
        }.should_not raise_error
      end

    end

    context "loading" do
      it "uses convential proxy env vars" do
        c = Config.load({environment: :production}, 'HTTP_PROXY' => 'http://foo.com:9872')
        c[:proxy_url].should == 'http://foo.com:9872'

        c = Config.load({environment: :production}, 'http_proxy' => 'http://bar.com:9872')
        c[:proxy_url].should == 'http://bar.com:9872'
      end

      it "normalizes convential proxy env vars" do
        # Curl doesn't require http:// prefix
        c = Config.load({environment: :production}, 'HTTP_PROXY' => 'foo.com:9872')
        c[:proxy_url].should == 'http://foo.com:9872'
      end

      it "prioritizes skylight's proxy env var" do
        c = Config.load({environment: :production},
          'SKYLIGHT_PROXY_URL' => 'http://foo.com',
          'HTTP_PROXY' => 'http://bar.com')

        c[:proxy_url].should == 'http://foo.com'
      end
    end

    context "#to_native_env" do

      let :config do
        Config.new(
          hostname: "test.local",
          root: "/test",

          # These are set in some envs and not others
          "daemon.ssl_cert_dir" => nil,
          "daemon.ssl_cert_path" => nil,
          "daemon.exec_path" => nil,
          "daemon.lib_path" => nil
        )
      end

      def get_env
        Hash[*config.to_native_env]
      end

      it "converts to env" do
        expect(get_env).to eq({
          "SKYLIGHT_VERSION"    => Skylight::VERSION,
          "SKYLIGHT_ROOT"       => "/test",
          "SKYLIGHT_HOSTNAME"   => "test.local",
          "SKYLIGHT_AUTH_URL"   => "https://auth.skylight.io/agent",
          "SKYLIGHT_LAZY_START" => "true",
          "SKYLIGHT_VALIDATE_AUTHENTICATION" => "false"
        })
      end

      it "includes keys only if value is set" do
        expect(get_env['SKYLIGHT_SESSION_TOKEN']).to be_nil

        config[:session_token] = "zomg"

        expect(get_env['SKYLIGHT_SESSION_TOKEN']).to eq("zomg")
      end

    end

    context "legacy settings" do
      it "remaps agent.sockfile_path" do
        c = Config.new(agent: { sockfile_path: "/foo/bar" })
        c[:'agent.sockfile_path'].should == '/foo/bar'
        c[:'daemon.sockdir_path'].should == '/foo/bar'

        env = Hash[*c.to_native_env]
        env['SKYLIGHT_AGENT_SOCKFILE_PATH'].should be_nil
        env['SKYLIGHT_SOCKDIR_PATH'].should == '/foo/bar'
      end
    end
  end
end
