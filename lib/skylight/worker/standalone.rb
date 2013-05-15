require 'socket'
require 'thread'
require 'rbconfig'
require 'fileutils'

module Skylight
  module Worker
    # Handle to the agent subprocess. Manages creation, communication, and
    # shutdown. Lazily spawns a thread that handles writing messages to the
    # unix domain socket
    class Standalone
      include Util::Logging

      SUBPROCESS_CMD = [
        File.join(RbConfig::CONFIG['bindir'], "#{RbConfig::CONFIG['ruby_install_name']}#{RbConfig::CONFIG['EXEEXT']}"),
        '-I', File.expand_path('../../..', __FILE__),
        File.expand_path('../../../skylight.rb', __FILE__) ]

      HELLO = Messages::Hello.new(version: VERSION, cmd: SUBPROCESS_CMD)

      attr_reader :pid, :lockfile, :sockfile_path

      def initialize(lockfile, sockfile_path)
        @pid  = nil
        @srv  = nil
        @sock = nil

        @lockfile = lockfile
        @sockfile_path = sockfile_path

        # Writer background processor will accept messages and write them to
        # the IPC socket
        @writer = Util::Task.new(100) { |m| writer_tick(m) }

        # Spawn (or detect) agent process immediately
        unless spawn
          raise "could not spawn agent"
        end
      end

      # Optimize for the common case: a single threaded rails server writing on
      # the main thread.
      #
      # Two edge cases:
      #
      # a) Multi threaded rails server. Spawn a worker thread and push all
      # messages to the thread.
      #
      #   - Unset master thread ID
      #
      # b) Single threaded rails server. Write fails, reopen connection (might
      # require spawning a new agent subprocess). Do this in a thread.
      #
      def send(msg)
        # Must be encodable
        return unless msg.respond_to?(:encode)
        @writer.submit(msg)
      end

      # Shutdown any side task threads. Let the agent process die on it's own.
      def shutdown
        # TODO: implement
        @writer.shutdown
      end

      # Shutdown any side task threads as well as the agent process
      def shutdown_all
        # TODO: implement
        shutdown
      end

    private

      # Handle exceptions from file opening here
      # TODO: handle invalid exiting
      def spawn
        check_permissions

        # Why 50? Why not...
        50.times do |i|
          begin
            if f = maybe_acquire_lock
              trace "standalone process lock acquired"
              @pid = spawn_worker(f)
            else
              @pid = read_lockfile
            end

            # Try reading the pid from the lockfile
            if @pid
              # Check if the sockfile has been created yet
              if sockfile?
                if sock = connect
                  trace "connected to worker; attempt=%d", i
                  write_msg(sock, HELLO)
                  @sock = sock
                  return true
                end
              end
            end

          ensure
            f.close rescue nil if f
          end

          sleep 0.1
        end

        false
      end

      def writer_tick(msg)
        2.times do
          unless sock = @sock
            # TODO: respawn the agent
          end

          if write_msg(sock, msg)
            return true
          end

          @sock = nil
          sock.close

          # TODO: Respawn the agent
          raise NotImplementedError
        end

        false
      end

      def write_msg(sock, msg)
        buf   = msg.encode.to_s
        frame = [ msg.message_id, buf.bytesize ].pack("LL")

        write(sock, frame) &&
          write(sock, buf)
      end

      SOCK_TIMEOUT_VAL = [ 0, 0.01 * 1_000_000 ].pack("l_2")

      # TODO: Handle configuring the socket with proper timeouts
      def connect
        sock = UNIXSocket.new(sockfile) rescue nil
        if sock
          sock.setsockopt Socket::SOL_SOCKET, Socket::SO_SNDTIMEO, SOCK_TIMEOUT_VAL
          sock
        end
      end

      def write(sock, msg, timeout = 0.01)
        msg = msg.to_s
        cnt = 50

        while 0 <= (cnt -= 1)
          ret = sock.syswrite msg rescue nil

          return true unless ret

          if ret == msg.bytesize
            return true
          elsif ret > 0
            msg = msg.byteslice(ret..-1)
          end
        end

        return false
      end

      # Spawn the worker process.
      def spawn_worker(f)
        # Before forking, truncate the file
        f.truncate(0)

        fork do
          # We be daemonizing
          Process.setsid
          exit if fork

          # null = File.open "/dev/null"
          # STDIN.reopen null
          # STDOUT.reopen null
          # STDERR.reopen null

          Server.exec(SUBPROCESS_CMD, f, nil, lockfile, sockfile_path)
        end
      ensure
        lockfile.close rescue nil
      end

      def check_permissions
        FileUtils.mkdir_p File.dirname(lockfile)
        # stuff
      end

      # Edgecases:
      # - directory missing
      # - invalid permissions
      def maybe_acquire_lock
        f = File.open lockfile, File::RDWR | File::CREAT

        if f.flock(File::LOCK_EX | File::LOCK_NB)
          f
        end
      end

      def read_lockfile
        pid = File.read(lockfile) rescue nil
        if pid =~ /^\d+$/
          pid.to_i
        end
      end

      def sockfile
        "#{sockfile_path}/skylight-#{pid}.sock"
      end

      def sockfile?
        File.exist?(sockfile)
      end

    end
  end
end
