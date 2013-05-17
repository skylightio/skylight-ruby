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

      attr_reader \
        :pid,
        :lockfile,
        :keepalive,
        :max_spawns,
        :spawn_window,
        :sockfile_path

      def initialize(lockfile, sockfile_path, server, keepalive)
        @pid  = nil
        @sock = nil

        unless lockfile && sockfile_path && server
          raise ArgumentError, "all arguments are required"
        end

        @spawns = []
        @server = server
        @lockfile = lockfile
        @keepalive = keepalive
        @sockfile_path = sockfile_path

        # Should be configurable
        @max_spawns = 3
        @spawn_window = 5 * 60

        # Writer background processor will accept messages and write them to
        # the IPC socket
        @writer = Util::Task.new(100, 1) { |m| writer_tick(m) }
      end

      def spawn(*args)
        return if @pid

        if __spawn(*args)
          @writer.spawn
          true
        end
      end

      def send(msg)
        return unless @pid

        unless msg.respond_to?(:encode)
          raise ArgumentError, "message not encodable"
        end

        @writer.submit(msg)
      end

      # Shutdown any side task threads. Let the agent process die on it's own.
      def shutdown
        # TODO: implement
        @writer.submit(:SHUTDOWN)
        @writer.shutdown
      end

      # Shutdown any side task threads as well as the agent process
      def shutdown_all
        # TODO: implement
        shutdown
      end

    private

      def __spawn(timeout = 5)
        if timeout < 2
          raise ArgumentError, "at least 2 seconds required"
        end

        start = Time.now

        if @spawns.length >= @max_spawns
          if @spawn_window >= (start - @spawns.first)
            trace "too many spawns in window"
            return false
          end

          @spawns.unshift
        end

        @spawns << start

        check_permissions

        lockf = File.open lockfile, File::RDWR | File::CREAT

        spawn_worker(lockf)

        while timeout >= (Time.now - start)
          if pid = read_lockfile
            if sockfile?(pid)
              if sock = connect(pid)
                trace "connected to unix socket; pid=%s", pid
                write_msg(sock, HELLO)
                @sock = sock
                @pid  = pid
                return true
              end
            end
          end

          sleep 0.1
        end

        trace "failed to spawn worker"
        return false

      ensure
        lockf.close rescue nil if lockf
      end

      def repair
        # Attempt to reconnect to the currently known agent PID. If the agent
        # is still healthy but is simply reloading itself, this should work
        # just fine.
        if sock = connect(@pid)
          trace "reconnected to worker"
          @sock = sock
          # TODO: Should HELLO be sent again?
          return true
        end

        # Attempt to respawn the agent process
        unless __spawn
          @pid  = nil
          @sock = nil
          return false
        end

        true
      end

      def writer_tick(msg)
        if :SHUTDOWN == msg
          trace "shuting down agent connection"
          @sock.close if @sock
          @pid = nil
        elsif msg
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
            exit 1
          end

          f.truncate(0)

          # Lock acquired, cleanup old sock files
          Dir["#{sockfile_path}/skylight-*.sock"].each do |sf|
            File.unlink(sf) rescue nil
          end

          pid = Process.pid.to_s

          # Write the pid
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

          @server.exec(SUBPROCESS_CMD, f, srv, lockfile, sockfile_path, keepalive)
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
