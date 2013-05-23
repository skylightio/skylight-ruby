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

    ret
  end

  def cleanup_all_spawned_workers
    (@spawned || []).each do |worker|
      worker.shutdown
    end
  end

  def kill(sig, pid)
    Process.kill(sig, pid)
  end

end
