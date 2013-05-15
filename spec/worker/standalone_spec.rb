require 'spec_helper'

describe 'Standalone worker' do

  def spawn_worker
    Skylight::Worker::Builder.new(sockfile_path: tmp).spawn
  end

  let :pid do
    File.read(tmp('skylight.pid')).to_i
  end

  context 'spawning the worker' do

    let! :worker do
      spawn_worker
    end

    it 'sets a pid file' do
      tmp('skylight.pid').should exist
    end

    it 'creates the unix domain socket' do
      tmp("skylight-#{pid}.sock").should exist
    end

    it 'sets the value to a different pid than the current process' do
      pid.should be > 0
      pid.should_not be == Process.pid
    end

    it 'creates a new agent process' do
      lambda { Process.getpgid(pid) }.should_not raise_error
    end

    it 'provides the pid' do
      spawn_worker.pid.should == pid
    end

    it 'only spawns one worker' do
      other = spawn_worker
      worker.pid.should == other.pid
    end

  end

end
