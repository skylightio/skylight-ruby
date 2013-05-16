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
    class Standalone
      include Util::Logging

      SUBPROCESS_CMD = [
        File.join(RbConfig::CONFIG['bindir'], "#{RbConfig::CONFIG['ruby_install_name']}#{RbConfig::CONFIG['EXEEXT']}"),
        '-I', File.expand_path('../../..', __FILE__),
        File.expand_path('../../../skylight.rb', __FILE__) ]

      HELLO = Messages::Hello.new(version: VERSION, cmd: SUBPROCESS_CMD)

      attr_reader :pid, :lockfile, :sockfile_path

      def initialize(lockfile, sockfile_path, server)
        @pid  = nil
        @sock = nil

        unless lockfile && sockfile_path && server
          raise ArgumentError, "all arguments are required"
        end

        @server = server
        @lockfile = lockfile
        @sockfile_path = sockfile_path

        # Writer background processor will accept messages and write them to
        # the IPC socket
        @writer = Util::Task.new(100, 1) { |m| writer_tick(m) }

        # @writer.spawn
      end

      def spawn(*args)
        return if @pid
        __spawn(*args)
      end

      def send(msg)
        unless msg.respond_to?(:encode)
          raise ArgumentError, "message not encodable"
        end

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
      #
      # Cases:
      #   - No lockfile
      #     * Create lockfile, on fail -> start over
      #
      #   - Lockfile empty
      #
      #   - Lockfile has pid, no sock
      #
      #   - Lockfile + agent booted
      #
      #   - Lockfile + no agent
      #
      def __spawn(timeout = 5)
        if timeout < 2
          raise ArgumentError, "at least 2 seconds required"
        end

        check_permissions

        r = true
        s = Time.now
        f = File.open lockfile, File::RDWR | File::CREAT | File::EXCL rescue nil

        while r
          # Only run once when there is an open handle to the lockfile
          r = false if f

          if f
            trace "spawning worker"
            # TODO: Track spawning
            spawn_worker(f)
          end

          pid = read_lockfile

          until pid && sockfile?(pid)
            elapsed = Time.now - s

            # If this is the last run, allow 5 seconds, otherwise allow 1
            break if r && elapsed > 1 || !r && elapsed > timeout

            sleep 0.1
            pid = read_lockfile
          end

          if sock = connect(pid)
            trace "connected to worker"
            write_msg(sock, HELLO)
            @sock = sock
            @pid = pid
            return true
          elsif r
            # We're going to try again
            f = File.open lockfile, File::RDWR | File::CREAT
          end
        end

        return false

      ensure
        f.close rescue nil if f


        # Why 50? Why not...
        # 50.times do |i|
        #   pid = nil

        #   begin
        #     if f = maybe_acquire_lock
        #       trace "standalone process lock acquired"
        #       pid = spawn_worker(f)
        #     else
        #       pid = read_lockfile
        #     end

        #     # Try reading the pid from the lockfile
        #     if pid
        #       # Check if the sockfile has been created yet
        #       if sockfile?(pid)
        #         trace "attempting socket connection"
        #         if sock = connect(pid)
        #           trace "connected to worker; attempt=%d", i
        #           write_msg(sock, HELLO)
        #           @sock = sock
        #           @pid  = pid
        #           return true
        #         end
        #       end
        #     end

        #   ensure
        #     f.close rescue nil if f
        #   end

        #   sleep 0.1
        # end

        # false
      end

      def repair
        # Attempt to reconnect to the currently known agent PID
        if sock = connect(@pid)
          trace "reconnected to worker"
          @sock = sock
          return true
        end

        # Attempt to respawn the agent process
        __spawn
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
        fork do
          Process.setsid
          exit if fork

          # Acquire exclusive file lock, exit otherwise
          unless f.flock(File::LOCK_EX | File::LOCK_NB)
            exit
          end

          pid = Process.pid.to_s

          # Write the pid
          f.truncate(0)
          f.write(pid)
          f.flush

          sf = sockfile(pid)
          File.unlink(sf) rescue nil

          srv = UNIXServer.new(sf)

          # TODO: Send logs to proper location
          # null = File.open "/dev/null"
          # STDIN.reopen null
          # STDOUT.reopen null
          # STDERR.reopen null

          @server.exec(SUBPROCESS_CMD, f, srv, lockfile, sockfile_path)
        end
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
