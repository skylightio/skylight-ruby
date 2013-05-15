require 'socket'
require 'skylight/version'

module Skylight
  autoload :Messages, 'skylight/messages'
  autoload :Worker,   'skylight/worker'

  module Util
    autoload :Logging, 'skylight/util/logging'
    autoload :Queue,   'skylight/util/queue'
    autoload :Task,    'skylight/util/task'
  end

  # ==== Vendor ====
  autoload :Beefcake, 'skylight/vendor/beefcake'

  # Called by the standalone agent
  if ENV[Worker::STANDALONE_ENV_KEY] == Worker::STANDALONE_ENV_VAL
    def fail(msg, code = 1)
      STDERR.ptus msg
      exit code
    end

    unless fd = ENV[Worker::LOCKFILE_ENV_KEY]
      fail "missing lockfile FD"
    end

    unless fd =~ /^\d+$/
      fail "invalid lockfile FD"
    end

    begin
      lockfile = IO.open(fd.to_i)
    rescue Exception => e
      fail "invalid lockfile FD: #{e.message}"
    end

    unless sockfile_path = ENV[Worker::SOCKFILE_PATH_KEY]
      fail "missing sockfile path"
    end

    unless lockfile_path = ENV[Worker::LOCKFILE_PATH]
      fail "missing lockfile path"
    end

    srv = nil
    if fd = ENV[Worker::UDS_SRV_FD_KEY]
      srv = UNIXServer.from_fd(fd.to_i)
    end

    server = Skylight::Worker::Server.new(
      lockfile,
      srv,
      lockfile_path,
      sockfile_path)

    server.run
  end
end
