require 'spec_helper'

describe 'Standalone worker' do

  let :pid do
    File.read(tmp('skylight.pid')).to_i
  end

  let :worker do
    spawn_worker
  end

  let :agent_strategy do
    'standalone'
  end

  context 'initial spawning' do

    it 'sets a pid file' do
      worker
      tmp('skylight.pid').should exist
    end

    it 'creates the unix domain socket' do
      worker
      tmp("skylight-#{pid}.sock").should exist
    end

    it 'sets the value to a different pid than the current process' do
      worker
      pid.should be > 0
      pid.should_not be == Process.pid
    end

    it 'creates a new agent process' do
      worker
      pid_exists?(pid).should be_true
    end

    it 'provides the pid' do
      worker
      spawn_worker.pid.should == pid
    end

    it 'only spawns one worker' do
      worker
      other = spawn_worker
      worker.pid.should == other.pid
    end

    it 'aborts if the lockfile location is not writable' do
      tmp.mkdir_p
      tmp.chmod(0555)
      lambda {
        worker
      }.should raise_error(Skylight::WorkerStateError)
    end

    it 'aborts if the lockfile exists but is not writable' do
      lockfile.touch
      lockfile.chmod(0444)
      lambda {
        spawn_worker
      }.should raise_error(Skylight::WorkerStateError)
    end

    it 'aborts if the sockfile location is not writable' do
      sockfile_path = tmp('socks')
      sockfile_path.mkdir_p
      sockfile_path.chmod(0555)
      lambda {
        spawn_worker sockfile_path: sockfile_path
      }.should raise_error(Skylight::WorkerStateError)
    end

  end

  context 'restarting' do

    it 'restarts the worker when the domain socket is closed' do
      pid = worker.pid
      pid.should_not be_nil
      kill 9, pid # The ultimate sacrifice
      lambda { worker.pid != pid }.should happen(5)
    end

    it 'restarts the worker when the lockfile is deleted' do
      pid = worker.pid
      worker.shutdown
      lockfile.rm
      lambda { !pid_exists?(pid) }.should happen(5)
    end

    it 'restarts the worker when the lockfile changes' do
      pid = worker.pid
      worker.shutdown
      File.open(lockfile, 'w') { |f| f.write "123345" }
      lambda { !pid_exists?(pid) }.should happen(5)
    end

    it 'restarts the worker when the sockfile is deleted' do
      pid = worker.pid
      worker.shutdown
      sockfile_path("skylight-#{pid}.sock").rm
      lambda { !pid_exists?(pid) }.should happen(5)
    end

  end

  context 'throttling restarts' do

    it 'restarts the worker at most 3 times per 5 minutes' do
      pid = worker.pid

      2.times do
        kill 9, pid
        lambda { worker.pid != pid }.should happen(5)
        pid = worker.pid
        pid.should_not be_nil
      end

      kill 9, pid
      lambda { worker.pid != pid }.should happen(5)
      worker.pid.should be_nil
    end

  end

  context 'handling inactivity' do

    it 'shutsdown when there are no client connections' do
      worker = spawn_worker keepalive: 1
      pid = worker.pid
      worker.shutdown
      lambda { !pid_exists?(pid) }.should happen(5)
    end

  end

  context 'reloading', :http do

    it 'reloads the agent when there is a new version' do
      start!

      testfile = tmp('reloading-test')
      version  = "#{Skylight::VERSION}.1"

      tmp("test.rb").write <<-RUBY
        require 'fileutils'
        FileUtils.touch("#{testfile}")
      RUBY

      worker.submit Skylight::Messages::Hello.build(version, [Skylight::RUBYBIN, tmp("test.rb").to_s])

      lambda { testfile.exist? }.should happen(5)
    end

  end

end unless defined?(JRUBY_VERSION)
