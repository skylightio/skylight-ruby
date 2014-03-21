require 'spec_helper'

describe Skylight::Config do

  context 'basic lookup' do

    let :config do
      Skylight::Config.new :foo => 'hello', 'bar' => 'omg'
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
      Skylight::Config.new :one => {
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
      Skylight::Config.new :one => {
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
      Skylight::Config.new foo: 'bar'
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
      Skylight::Config.new('production',
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
      Skylight::Config.new(
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
      config = Skylight::Config.new
      config['report.ssl'].should be_true
    end

    it 'uses values over defaults' do
      config = Skylight::Config.new report: { ssl: false }
      config['report.ssl'].should be_false
    end

    it 'uses nil values over defaults' do
      config = Skylight::Config.new report: { ssl: nil }
      config['report.ssl'].should be_nil
    end

  end

  context 'hostname' do

    it 'defaults to the current hostname' do
      config = Skylight::Config.new
      config[:hostname].should == Socket.gethostname
    end

    it 'can be overridden' do
      config = Skylight::Config.new hostname: 'lulz'
      config[:hostname].should == 'lulz'
    end

  end

  context 'loading from YAML' do

    let :file do
      tmp('skylight.yml')
    end

    let :config do
      Skylight::Config.load(file, 'production', {
        'foo'                     => 'fail',
        'application'             => 'no',
        'SKYLIGHT_AUTHENTICATION' => 'my-token',
        'SKYLIGHT_APPLICATION'    => 'my-app'})
    end

    before :each do
      file.write <<-YML
application: nope
authentication: nope
zomg: hello
foo: bar
stuff: nope
report:
  ssl: true

production:
  stuff: waaa
      YML
    end

    it 'sets the configuration' do
      config['zomg'].should == 'hello'
    end

    it 'can load the application from an environment variable' do
      config['application'].should == 'my-app'
    end

    it 'can load the token from an environment variable' do
      config['authentication'].should == 'my-token'
    end

    it 'ignores unknown env keys' do
      config['foo'].should == 'bar'
    end

    it 'loads nested config variables' do
      config['report.ssl'].should == true
    end

    it 'still overrides' do
      config['stuff'].should == 'waaa'
    end

  end

  context 'legacy ENV key prefix' do

    let :file do
      tmp('skylight.yml')
    end

    before :each do
      file.write <<-YML
application: nope
authentication: nope
      YML
    end

    let :config do
      Skylight::Config.load(file, 'production', {
        'foo'               => 'fail',
        'application'       => 'no',
        'SK_AUTHENTICATION' => 'my-token',
        'SK_APPLICATION'    => 'my-app'})
    end

    it 'loads the authentication key' do
      config[:'authentication'].should == 'my-token'
    end

    it 'loads the application id' do
      config[:'application'].should == 'my-app'
    end

  end

  context 'to ENV map' do

    it 'has tests'

  end

  context "validations" do

    let :config do
      Skylight::Config.new(authentication: "testtoken")
    end

    it "is valid" do
      lambda { config.validate! }.should_not raise_error
    end

    Skylight::Config::REQUIRED.each do |key, name|
      it "requires #{key}" do
        config[key] = nil
        lambda { config.validate! }.should raise_error(Skylight::ConfigError, "#{name} required")
      end
    end

    it "does not allow agent.interval to be a non-zero integer" do
      lambda {
        config['agent.interval'] = "abc"
      }.should raise_error(Skylight::ConfigError, "invalid value for agent.interval (abc), must be an integer greater than 0")

      lambda {
        config['agent.interval'] = -1
      }.should raise_error(Skylight::ConfigError, "invalid value for agent.interval (-1), must be an integer greater than 0")

      lambda {
        config['agent.interval'] = 5
      }.should_not raise_error
    end

  end

end
