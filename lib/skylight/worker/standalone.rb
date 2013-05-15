require 'socket'
require 'thread'
require 'rbconfig'
require 'fileutils'

module Skylight
  module Worker
    # Handle to the agent subprocess. Manages creation, communication, and
    # shutdown. Lazily spawns a thread that handles writing messages to the
    # unix domain socket
    #
    # TODO:
    #   - Handle the sock file changing
    class Standalone
      include Util::Logging

      SUBPROCESS_CMD = [
        File.join(RbConfig::CONFIG['bindir'], "#{RbConfig::CONFIG['ruby_install_name']}#{RbConfig::CONFIG['EXEEXT']}"),
        '-I', File.expand_path('../../..', __FILE__),
        File.expand_path('../../../skylight.rb', __FILE__) ]

      HELLO = Messages::Hello.new(version: VERSION, cmd: SUBPROCESS_CMD)

      attr_reader :pid, :lockfile, :sockfile_path

      def initialize(lockfile, sockfile_path, spawner)
        @pid  = nil
        @sock = nil

        unless lockfile && sockfile_path && spawner
          raise ArgumentError, "all arguments are required"
        end

        @spawner = spawner
        @lockfile = lockfile
        @sockfile_path = sockfile_path

        # Writer background processor will accept messages and write them to
        # the IPC socket
        @writer = Util::Task.new(100, 1) { |m| writer_tick(m) }

        # Spawn (or detect) agent process immediately
        unless spawn
          raise "could not spawn agent"
        end

        @writer.spawn
      end

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
          pid = nil

          begin
            if f = maybe_acquire_lock
              trace "standalone process lock acquired"
              pid = spawn_worker(f)
            else
              pid = read_lockfile
            end

            # Try reading the pid from the lockfile
            if pid
              # Check if the sockfile has been created yet
              if sockfile?(pid)
                trace "attempting socket connection"
                if sock = connect(pid)
                  trace "connected to worker; attempt=%d", i
                  write_msg(sock, HELLO)
                  @sock = sock
                  @pid  = pid
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

      def repair
        # Attempt to reconnect to the currently known agent PID
        if sock = connect(@pid)
          trace "reconnected to worker"
          @sock = sock
          return true
        end

        # Attempt to respawn the agent process
        spawn
      end

      def writer_tick(msg)
        if msg
          handle(msg)
        else
          trace "Testing socket"

          begin
            @sock.read_nonblock(1)
          rescue Errno::EWOULDBLOCK, Errno::EAGAIN, Errno::EINTR
          rescue Exception => e
            trace "bad socket: #{e}"
            unless repair
              raise WorkerStateError, "could not repair connection to agent"
            end
          end

          true
        end
      rescue WorkerStateError => e
        error "skylight shutting down: %s", e.message
        false
      end

      def handle(msg)
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
      def connect(pid)
        sock = UNIXSocket.new(sockfile(pid)) rescue nil
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

        # Spawns new process and returns PID
        @spawner.spawn(SUBPROCESS_CMD, f, nil, lockfile, sockfile_path)
      ensure
        lockfile.close rescue nil
      end

      def check_permissions
        lockfile_root = File.dirname(lockfile)

        FileUtils.mkdir_p lockfile_root
        FileUtils.mkdir_p sockfile_path

        if File.exist?(lockfile)
          if !FileTest.writable?(lockfile)
            raise WorkerStateError, "`#{lockfile}` not writable"
          end
        else
          if !FileTest.writable?(lockfile_root)
            raise WorkerStateError, "`#{lockfile_root}` not writable"
          end
        end

        unless FileTest.writable?(sockfile_path)
          raise WorkerStateError, "`#{sockfile_path}` not writable"
        end
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

      def sockfile(pid)
        "#{sockfile_path}/skylight-#{pid}.sock"
      end

      def sockfile?(pid)
        File.exist?(sockfile(pid))
      end

    end
  end
end
