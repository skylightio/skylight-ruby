require 'spec_helper'

module Skylight
  describe Config do

    let :config do
      Config.new
    end

    let :yaml_config do
      Config.load_from_yaml(File.expand_path("../fixtures/sample_config.yml", __FILE__))
    end

    it "has correct defaults" do
      config.authentication_token.should == "8yagFhG61tYeY4j18K8+VpI0CyG4sht5J2Oj7RQL05RhcHBsaWNhdGlvbl9pZHM9Zm9vJnJvbGU9YWdlbnQ="
      config.ssl.should == true
      config.deflate.should == true
      config.host.should == "agent.skylight.io"
      config.port.should == 443
      config.samples_per_interval.should == 100
      config.interval.should == 5
      config.max_pending_traces.should == 500
      config.protocol.should be_an_instance_of(JsonProto)
      config.logger.should be_an_instance_of(Logger)
      config.logger.level.should == Logger::INFO
    end

    it "has boolean aliases" do
      config.ssl?.should == true
      config.deflate?.should == true
    end

    it "can get and set log_level" do
      config.log_level = Logger::INFO
      config.log_level.should == Logger::INFO
      config.logger.level.should == Logger::INFO
    end

    it "can be loaded from YAML" do
      yaml_config.authentication_token.should == "abc123"
      yaml_config.ssl.should == false
      yaml_config.deflate.should == false
      yaml_config.host.should == "localhost"
      yaml_config.port.should == 8080
      yaml_config.samples_per_interval.should == 50
      yaml_config.interval.should == 10
      yaml_config.max_pending_traces.should == 700
      yaml_config.protocol.should be_an_instance_of(JsonProto)
      yaml_config.log_level.should == Logger::INFO
    end

  end
end
