require 'socket'
require 'thread'
require 'fileutils'

# TODO: Handle cool-off
module Skylight
  module Worker
    # Handle to the agent subprocess. Manages creation, communication, and
    # shutdown. Lazily spawns a thread that handles writing messages to the
    # unix domain socket
    #
    class Standalone
      include Util::Logging

      SUBPROCESS_CMD = [
        RUBYBIN,
        '-I', File.expand_path('../../..', __FILE__),
        File.expand_path('../../../skylight.rb', __FILE__) ]

      LOCK = Mutex.new

      attr_reader \
        :pid,
        :config,
        :lockfile,
        :keepalive,
        :max_spawns,
        :spawn_window,
        :sockfile_path

      def initialize(config, lockfile, server)
        @pid  = nil
        @sock = nil

        unless config && lockfile && server
          raise ArgumentError, "all arguments are required"
        end

        @me = Process.pid
        @config = config
        @spawns = []
        @server = server
        @lockfile = lockfile
        @keepalive = config[:'agent.keepalive']
        @sockfile_path = config[:'agent.sockfile_path']

        # Should be configurable
        @max_spawns = 3
        @spawn_window = 5 * 60

        # Writer background processor will accept messages and write them to
        # the IPC socket
        @writer = build_queue
      end

      def spawn(*args)
        return if @pid

        if __spawn(*args)
          @writer.spawn
          true
        end
      end

      def submit(msg)
        unless msg.respond_to?(:encode) || msg.respond_to?(:native_serialize)
          raise ArgumentError, "message not encodable"
        end

        return unless @pid

        if @me != Process.pid
          handle_fork
        end

        @writer.submit(msg, @me)
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

      def __spawn(timeout = 10)
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
                write_msg(sock, build_hello)
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
        @sock.close rescue nil if @sock

        t { "repairing socket" }

        # Attempt to reconnect to the currently known agent PID. If the agent
        # is still healthy but is simply reloading itself, this should work
        # just fine.
        if sock = connect(@pid)
          t { "reconnected to worker" }
          @sock = sock
          # TODO: Should HELLO be sent again?
          return true
        end

        debug "failed to reconnect -- attempting worker respawn"

        # Attempt to respawn the agent process
        unless __spawn
          debug "could not respawn -- shutting down"

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
            return false unless repair
            sock = @sock
          end

          if write_msg(sock, msg)
            return true
          end

          @sock = nil
          sock.close rescue nil

          unless repair
            return false
          end
        end

        debug "could not handle message; msg=%s", msg.class

        false
      end

      def write_msg(sock, msg)
        t { "writing a #{msg.class} on the wire" }
        id = Messages::KLASS_TO_ID.fetch(msg.class)
        buf = msg.serialize

        frame = [ id, buf.bytesize ].pack("LL")

        write(sock, frame) && write(sock, buf)
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

      def write(sock, msg, timeout = 5)
        msg = msg.to_s
        cnt = 10

        begin
          while true
            res = sock.write_nonblock(msg)

            if res == msg.bytesize
              return true
            elsif res > 0
              msg = msg.byteslice(res..-1)
              cnt = 10
            else
              if 0 <= (cnt -= 1)
                t { "write failed -- max attempts" }
                return false
              end
            end
          end
        rescue Errno::EAGAIN, Errno::EWOULDBLOCK
          _, socks, = IO.select([], [sock], [], timeout)
          unless socks == [sock]
            t { "write timed out" }
            return false
          end
          retry
        rescue Errno::EINTR
          raise
        rescue SystemCallError => e
          t { fmt "write failed; err=%s", e.class }
          return false
        end
      end

      # Spawn the worker process.
      def spawn_worker(f)
        pid = fork do
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

          unless ENV[TRACE_ENV_KEY]
            null = File.open "/dev/null", File::RDWR
            STDIN.reopen null
            STDOUT.reopen null
            STDERR.reopen null
          end

          # Cleanup the ENV
          ENV['RUBYOPT'] = nil

          @server.exec(SUBPROCESS_CMD, @config, f, srv, lockfile)
        end

        Process.detach(pid)
      end

      # If the process was forked, create a new queue and restart the worker
      def handle_fork
        LOCK.synchronize do
          if @me != Process.pid
            trace "process forked; recovering"
            # Update the current process ID
            @me = Process.pid

            # Deal w/ the inherited socket
            @sock.close rescue nil if @sock
            @sock = nil

            @writer = build_queue
            @writer.spawn
          end
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

      def build_hello
        Messages::Hello.build(VERSION, SUBPROCESS_CMD)
      end

      def build_queue
        Util::Task.new(100, 1) { |m| writer_tick(m) }
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
