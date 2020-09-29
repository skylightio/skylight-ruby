require "spec_helper"

module Skylight
  describe UserConfig do
    let :config do
      UserConfig.new(Config.load)
    end

    def set_file_path(path)
      allow(config).to receive(:file_path).and_return(File.expand_path(path, __dir__))
      config.reload
    end

    def with_env(vars)
      original = ENV.to_hash
      vars.each { |k, v| ENV[k] = v }

      begin
        yield
      ensure
        ENV.replace(original)
      end
    end

    describe "#file_path" do
      it "preferably uses SKYLIGHT_USER_CONFIG_PATH" do
        dir = File.expand_path(Dir.mktmpdir)
        config_path = File.join(dir, "skylight_user_config_path")
        FileUtils.touch(config_path)
        Dir.chdir(dir) do
          with_env("SKYLIGHT_USER_CONFIG_PATH" => config_path) do
            expect(config.file_path).to eq(config_path)
          end
        end
      end

      it "uses HOME if available" do
        with_env("HOME" => "/users/tester") do
          expect(config.file_path).to eq("/users/tester/.skylight")
        end
      end

      it "uses Etc.getpwuid if no HOME" do
        allow(Etc).to receive(:getpwuid).and_return(double(dir: "/users/other-tester"))
        with_env("HOME" => nil) do
          expect(config.file_path).to eq("/users/other-tester/.skylight")
        end
      end

      it "uses USER if no HOME or Etc.getpwuid information" do
        pending "hard to set up correct environment"

        # Not 100% sure this stub is correct
        allow(Etc).to receive(:getpwuid).and_return(double(dir: nil))
        with_env("HOME" => nil, "USER" => "another-tester") do
          expect(config.file_path).to eq("/users/another-tester/.skylight")
        end
      end

      it "raises if no USER, Etc.getpwuid, or HOME" do
        # Not 100% sure this stub is correct
        allow(Etc).to receive(:getpwuid).and_return(double(dir: nil))
        with_env("HOME" => nil, "USER" => nil) do
          expect do
            config.file_path
          end.to raise_error(ConfigError, "The Skylight `user_config_path` must be defined since the home directory " \
                                          "cannot be inferred")
        end
      end
    end

    it "has defaults" do
      set_file_path "missing"

      # SKYLIGHT_DISABLE_DEV_WARNING is set for normal specs
      with_env("SKYLIGHT_DISABLE_DEV_WARNING" => nil) do
        expect(config.disable_dev_warning?).to be_falsy
      end
    end

    it "loads from file" do
      set_file_path "../support/skylight_user_config.yml"
      expect(config.disable_dev_warning?).to eq(true)
      expect(config.disable_env_warning?).to eq(false)
    end

    it "writes to a new file" do
      set_file_path "../support/skylight_user_config_new.yml"

      # SKYLIGHT_DISABLE_DEV_WARNING is set for normal specs
      with_env("SKYLIGHT_DISABLE_DEV_WARNING" => nil) do
        expect(config.disable_dev_warning?).to be_falsy
        config.disable_dev_warning = true

        expect(config.disable_env_warning?).to be_falsy
        config.disable_env_warning = true

        config.save
        config.reload

        expect(config.disable_dev_warning?).to eq(true)
        expect(config.disable_env_warning?).to eq(true)

        yaml = YAML.load_file(config.file_path)
        expect(yaml).to include("disable_dev_warning" => true)
        expect(yaml).to include("disable_env_warning" => true)
      end
    ensure
      FileUtils.rm(config.file_path)
    end
  end
end
