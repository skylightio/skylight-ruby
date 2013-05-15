module SpecHelper

  def pid_exists?(pid)
    !!Process.getpgid(pid) rescue false
  end

  def spawn_worker(opts = {})
    @spawned ||= []
    opts = { sockfile_path: sockfile_path }.merge(opts)
    ret  = Skylight::Worker::Builder.new(opts).spawn
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
