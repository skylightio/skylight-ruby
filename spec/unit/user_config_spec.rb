require 'spec_helper'

module Skylight
  describe UserConfig do

    let :config do
      UserConfig.new
    end

    def set_file_path(path)
      allow(config).to receive(:file_path).and_return(File.expand_path(path, __FILE__))
      config.reload
    end

    before(:each) do
      set_file_path("missing")
    end

    it "has defaults" do
      expect(config.disable_dev_warning?).to be_falsy
    end

    it "loads from file" do
      set_file_path "../../support/skylight_user_config.yml"
      expect(config.disable_dev_warning?).to eq(true)
      expect(config.disable_env_warning?).to eq(false)
    end

    it "writes to a new file" do
      begin
        set_file_path "../../support/skylight_user_config_new.yml"

        expect(config.disable_dev_warning?).to be_falsy
        config.disable_dev_warning = true

        expect(config.disable_env_warning?).to be_falsy
        config.disable_env_warning = true

        config.save
        config.reload

        expect(config.disable_dev_warning?).to eq(true)
        expect(config.disable_env_warning?).to eq(true)

        yaml = YAML.load_file(config.file_path)
        expect(yaml).to include('disable_dev_warning' => true)
        expect(yaml).to include('disable_env_warning' => true)
      ensure
        FileUtils.rm(config.file_path)
      end
    end

  end
end
