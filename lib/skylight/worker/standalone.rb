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

      HELLO = Messages::Hello.new(version: VERSION)

      attr_reader :pid

      def initialize
        @pid  = nil
        @srv  = nil
        @sock = nil

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

        # Why 90? Why not...
        90.times do |i|
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
            if f
              trace "closing lockfile"
              f.close rescue nil
            end
          end

          sleep 0.01
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

        args = []
        args << {
          STANDALONE_ENV_KEY => STANDALONE_ENV_VAL,
          LOCKFILE_PATH      => lockfile,
          LOCKFILE_ENV_KEY   => f.fileno.to_s,
          SOCKFILE_PATH_KEY  => sockfile_path }

        args << rubybin << '-I' << include_path << skylight_rb

        unless RUBY_VERSION < '1.9'
          fd = f.fileno.to_i
          args << { fd => fd }
        end

        fork do
          exec(*args)
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

      def lockfile
        "tmp/skylight.pid"
      end

      def sockfile_path
        "tmp"
      end

      def include_path
        File.expand_path('../../..', __FILE__)
      end

      def skylight_rb
        File.expand_path('../../../skylight.rb', __FILE__)
      end

      def rubybin
        c = RbConfig::CONFIG
        File.join(
          c['bindir'],
          "#{c['ruby_install_name']}#{c['EXEEXT']}")
      end
    end
  end
end
