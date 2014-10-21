module SpecHelper

  def pid_exists?(pid)
    !!Process.getpgid(pid) rescue false
  end

  def spawn_worker(opts = {})
    @spawned ||= []

    c = test_config_values.dup
    c[:agent] = c[:agent].merge(opts)

    ret = Skylight::Worker::Builder.new(c).build
    ret.spawn
    @spawned << ret

    elapsed = 0
    pid = nil
    timeout = WORKER_SPAWN_TIMEOUT || 5

    while true
      pid = ret.pid
      break if pid
      raise "Unable to spawn worker" if elapsed > timeout

      elapsed += 0.1
      sleep 0.1
    end

    ret
  end

  def cleanup_all_spawned_workers
    (@spawned || []).each do |worker|
      worker.shutdown
    end

    if lockfile.exist?
      begin
      pid = File.read(lockfile)
      rescue
      end

      if pid =~ /^\d+$/
        pid = pid.to_i

        # Poor man's waitpid. Implemented this way in order to work
        # around the fact that the pid we are attempting to wait on is
        # not a child of the current process.
        begin
          kill "TERM", pid

          while true
            kill 0, pid
          end
        rescue Errno::ESRCH
        end
      end
    end
  end

  def kill(sig, pid)
    Process.kill(sig, pid)
  end

end
