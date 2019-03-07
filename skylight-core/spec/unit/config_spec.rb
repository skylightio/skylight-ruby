require "spec_helper"

module Skylight::Core
  describe Config do
    def with_file(opts = {})
      f = Tempfile.new("foo")
      if opts[:writable] == false
        allow(FileTest).to receive(:writable?).and_call_original
        allow(FileTest).to receive(:writable?).with(f.path) { false }
      end

      yield f
    ensure
      f.close
      f.unlink
    end

    def with_dir(opts = {})
      Dir.mktmpdir do |d|
        FileUtils.mkdir("#{d}/nested")

        if opts[:writable] == false
          allow(FileTest).to receive(:writable?).and_call_original
          allow(FileTest).to receive(:writable?).with("#{d}/nested") { false }
        end

        yield "#{d}/nested"
      end
    end

    context "basic lookup" do
      let :config do
        Config.new :foo => "hello", "bar" => "omg"
      end

      it "looks keys up with strings" do
        expect(config["foo"]).to eq("hello")
        expect(config["bar"]).to eq("omg")
      end

      it "looks keys up with symbols" do
        expect(config[:foo]).to eq("hello")
        expect(config[:bar]).to eq("omg")
      end
    end

    context "1 level nested lookup" do
      let :config do
        Config.new one: { :foo => "hello", "bar" => "omg" }
      end

      it "looks keys up with strings" do
        expect(config["one.foo"]).to eq("hello")
        expect(config["one.bar"]).to eq("omg")
      end

      it "looks keys up with symbols" do
        expect(config[:'one.foo']).to eq("hello")
        expect(config[:'one.bar']).to eq("omg")
      end
    end

    context "2 level nested lookup" do
      let :config do
        Config.new one: {
          two: {
            :foo => "hello", "bar" => "omg"
          }
        }
      end

      it "looks keys up with strings" do
        expect(config["one.two.foo"]).to eq("hello")
        expect(config["one.two.bar"]).to eq("omg")
      end

      it "looks keys up with symbols" do
        expect(config[:'one.two.foo']).to eq("hello")
        expect(config[:'one.two.bar']).to eq("omg")
      end
    end

    context "lookup with defaults" do
      let :config do
        Config.new foo: "bar"
      end

      context "with a value" do
        it "returns the value if key is present" do
          expect(config["foo", "missing"]).to eq("bar")
        end

        it "returns the default if key is missing" do
          expect(config["bar", "missing"]).to eq("missing")
        end
      end

      context "with a block" do
        it "returns the value if key is present" do
          expect(config.get("foo") { "missing" }).to eq("bar")
        end

        it "calls the block if key is missing" do
          expect(config.get("bar") { "missing" }).to eq("missing")
        end
      end
    end

    context "environment scopes" do
      let :config do
        Config.new(
          "production",
          foo:    "bar",
          one:    1,
          zomg:   "YAY",
          nested: { "wat" => "w0t", "yes" => "no" },
          production: {
            foo:    "baz",
            two:    2,
            zomg:   nil,
            nested: { "yes" => "YES" }
          },
          staging: {
            foo:  "no",
            three: 3
          }
        )
      end

      it "prioritizes the environment config over the default" do
        expect(config[:foo]).to eq("baz")
        expect(config[:two]).to eq(2)
      end

      it "merges nested values" do
        expect(config["nested.wat"]).to eq("w0t")
        expect(config["nested.yes"]).to eq("YES")
      end

      it "still can access root values" do
        expect(config[:one]).to eq(1)
      end

      it "allows nil keys to override defaults" do
        expect(config[:zomg]).to be_nil
      end

      it "can access the environment configs explicitly" do
        expect(config["production.foo"]).to eq("baz")
      end

      it "can still access other environment configs explicitly" do
        expect(config["staging.foo"]).to eq("no")
      end
    end

    context "priority keys" do
      let :config do
        Config.new(
          "production",
          foo: "bar",
          nested: { foo: "bar", "baz" => "zomg" },
          production: {
            foo: "baz"
          },
          priority: {
            foo: "win",
            one: "1",
            "nested.foo" => "p"
          }
        )
      end

      it "is available as a top level key" do
        expect(config[:one]).to eq("1")
        expect(config["one"]).to eq("1")
      end

      it "takes priority over default values and environment scoped values" do
        expect(config[:foo]).to eq("win")
      end

      it "merges nested keys" do
        expect(config["nested.foo"]).to eq("p")
        expect(config["nested.baz"]).to eq("zomg")
      end
    end

    context "defaults" do
      it "uses defaults" do
        config = Config.new
        expect(config["heroku.dyno_info_path"]).to eq("/etc/heroku/dyno")
      end

      it "uses values over defaults" do
        config = Config.new heroku: { dyno_info_path: "/test" }
        expect(config["heroku.dyno_info_path"]).to eq("/test")
      end

      it "uses nil values over defaults" do
        config = Config.new heroku: { dyno_info_path: nil }
        expect(config["heroku.dyno_info_path"]).to be_nil
      end
    end

    context "duration" do
      it "assumes durations are seconds" do
        c = Config.new foo: "123"
        expect(c.duration_ms(:foo)).to eq(123_000)
      end

      it "parses explicit second units" do
        c = Config.new foo: "123sec"
        expect(c.duration_ms(:foo)).to eq(123_000)
      end

      it "parses ms" do
        c = Config.new foo: "123ms"
        expect(c.duration_ms(:foo)).to eq(123)
      end

      it "returns nil if there is no value" do
        c = Config.new
        expect(c.duration_ms(:foo)).to be_nil
      end
    end

    context "loading from YAML" do
      let :file do
        tmp("skylight.yml")
      end

      let :config do
        Config.load({ file: file, environment: "production" },
                    "foo"                     => "fail",
                    "SKYLIGHT_LOG_FILE"       => "production.log",
                    "SKYLIGHT_ALERT_LOG_FILE" => "alert.log")
      end

      context "valid" do
        before :each do
          file.write <<-YML
  authentication: invalid.log
  zomg: hello
  foo: bar
  stuff: nope
  proxy_url: 127.0.0.1
  report:
    ssl: true

  production:
    stuff: waaa

  erb: <%= 'interpolated' %>
          YML
        end

        it "sets the configuration" do
          expect(config["zomg"]).to eq("hello")
        end

        it "can load the token from an environment variable" do
          expect(config["log_file"]).to eq("production.log")
        end

        it "ignores unknown env keys" do
          expect(config["foo"]).to eq("bar")
        end

        it "loads nested config variables" do
          expect(config["production.stuff"]).to eq("waaa")
        end

        it "still overrides" do
          expect(config["stuff"]).to eq("waaa")
        end

        it "interpolates ERB" do
          expect(config["erb"]).to eq("interpolated")
        end

        it "sets proxy_url" do
          expect(config["proxy_url"]).to eq("127.0.0.1")
        end
      end

      context "invalid" do
        it "has useable error for empty files" do
          file.write ""
          expect { config }.to raise_error(ConfigError, "could not load config file; msg=empty file")
        end

        it "has useable error for files with only newlines" do
          file.write "\n"
          expect { config }.to raise_error(ConfigError, "could not load config file; msg=empty file")
        end

        it "has useable error for files with arrays" do
          file.write "- foo\n- bar"
          expect { config }.to raise_error(ConfigError, "could not load config file; msg=invalid format")
        end
      end
    end

    context "legacy ENV key prefix" do
      let :file do
        tmp("skylight.yml")
      end

      before :each do
        file.write <<-YML
  log_file: original.log
        YML
      end

      let :config do
        Config.load({ file: file, environment: "production" },
                    "foo"         => "fail",
                    "SK_LOG_FILE" => "test.log")
      end

      it "loads the authentication key" do
        expect(config[:log_file]).to eq("test.log")
      end
    end

    context "loggers" do
      def log_out(logger)
        # If this stops working, consider switching to checking the actual output of STDOUT or the IO instead.
        logger.instance_variable_get(:@logdev).dev
      end

      it "creates a logger" do
        c = Config.new(log_file: "-")
        expect(log_out(c.logger)).to eq(STDOUT)

        with_file do |f|
          c = Config.new(log_file: f.path)
          expect(log_out(c.logger).path).to eq(f.path)
        end
      end

      it "creates an alert_logger" do
        c = Config.new(alert_log_file: "-")
        out = log_out(c.alert_logger)
        expect(out).to be_a(Util::AlertLogger)
        expect(log_out(out.instance_variable_get(:@logger))).to eq(STDOUT)

        with_file do |f|
          c = Config.new(alert_log_file: f.path)
          expect(log_out(c.alert_logger).path).to eq(f.path)
        end
      end
    end

    context "validations" do
      let :config do
        Config.new(authentication: "testtoken")
      end

      it "is valid" do
        expect { config.validate! }.to_not raise_error
      end

      Config.required_keys.each do |key, name|
        it "requires #{key}" do
          config[key] = nil
          expect { config.validate! }.to raise_error(ConfigError, "#{name} required")
        end
      end

      context "permissions" do
        it "requires the log_file file to be writeable if it exists" do
          with_file(writable: false) do |f|
            config.set(:log_file, f.path)

            expect do
              config.validate!
            end.to raise_error(ConfigError, "File `#{f.path}` is not writable. Please set log_file in your config to a writable path")
          end
        end

        it "requires the log_file directory to be writeable if file doesn't exist" do
          with_dir(writable: false) do |d|
            config.set(:log_file, "#{d}/bar")

            expect do
              config.validate!
            end.to raise_error(ConfigError, "Directory `#{d}` is not writable. Please set log_file in your config to a writable path")
          end
        end

        it "requires the alert_log_file file to be writeable if it exists" do
          with_file(writable: false) do |f|
            config.set(:alert_log_file, f.path)

            expect do
              config.validate!
            end.to raise_error(ConfigError, "File `#{f.path}` is not writable. Please set alert_log_file in your config to a writable path")
          end
        end

        it "requires the alert_log_file directory to be writeable if file doesn't exist" do
          with_dir(writable: false) do |d|
            config.set(:alert_log_file, "#{d}/bar")

            expect do
              config.validate!
            end.to raise_error(ConfigError, "Directory `#{d}` is not writable. Please set alert_log_file in your config to a writable path")
          end
        end
      end
    end

    context "loading" do
      it "uses convential proxy env vars" do
        c = Config.load({ environment: :production }, "HTTP_PROXY" => "http://foo.com:9872")
        expect(c[:proxy_url]).to eq("http://foo.com:9872")

        c = Config.load({ environment: :production }, "http_proxy" => "http://bar.com:9872")
        expect(c[:proxy_url]).to eq("http://bar.com:9872")
      end

      it "uses unconvential proxy env vars" do
        c = Config.load({ environment: :production }, "HTTP_PROXY" => "xyz://foo.com:9872")
        expect(c[:proxy_url]).to eq("xyz://foo.com:9872")
      end

      it "normalizes convential proxy env vars" do
        # Curl doesn't require http:// prefix
        c = Config.load({ environment: :production }, "HTTP_PROXY" => "foo.com:9872")
        expect(c[:proxy_url]).to eq("http://foo.com:9872")
      end

      it "skips empty proxy env vars" do
        c = Config.load({ environment: :production }, "HTTP_PROXY" => "")
        expect(c[:proxy_url]).to be_nil
      end

      it "skips nil proxy env vars" do
        c = Config.load(environment: :production)
        expect(c[:proxy_url]).to be_nil
      end

      it "prioritizes skylight's proxy env var" do
        c = Config.load({ environment: :production },
                        "SKYLIGHT_PROXY_URL" => "http://foo.com",
                        "HTTP_PROXY" => "http://bar.com")

        expect(c[:proxy_url]).to eq("http://foo.com")
      end
    end

    context "#to_native_env" do
      let :config do
        Config.new(root: "/tmp")
      end

      def get_env
        Hash[*config.to_native_env]
      end

      it "converts to env" do
        expect(get_env).to eq(
          "SKYLIGHT_VERSION"    => Skylight::Core::VERSION,
          "SKYLIGHT_ROOT"       => "/tmp"
        )
      end

      it "includes keys only if value is set" do
        expect(get_env["SKYLIGHT_PROXY_URL"]).to be_nil

        config[:proxy_url] = "127.0.0.1"

        expect(get_env["SKYLIGHT_PROXY_URL"]).to eq("127.0.0.1")
      end
    end
  end
end
