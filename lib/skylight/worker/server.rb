require 'socket'

module Skylight
  module Worker
    # TODO:
    #   - Shutdown if no connections for over a minute
    class Server

      include Util::Logging

      attr_reader :pid, :lockfile_path, :sockfile_path

      def initialize(lockfile, srv, lockfile_path, sockfile_path)
        unless lockfile && srv
          raise ArgumentError, "lockfile and unix domain server socket are required"
        end

        @pid           = Process.pid
        @run           = true
        @socks         = []
        @server        = srv
        @lockfile      = lockfile
        @collector     = Collector.new
        @connections   = {}
        @lockfile_path = lockfile_path
        @sockfile_path = sockfile_path
      end

      def self.exec(cmd, lockfile, srv, lockfile_path, sockfile_path)
        env = {
          STANDALONE_ENV_KEY => STANDALONE_ENV_VAL,
          LOCKFILE_PATH      => lockfile_path,
          LOCKFILE_ENV_KEY   => lockfile.fileno.to_s,
          SOCKFILE_PATH_KEY  => sockfile_path }

        if srv
          env[UDS_SRV_FD_KEY] = srv.fileno.to_s
        end

        opts = {}
        args = [env] + cmd + [opts]

        unless RUBY_VERSION < '1.9'
          [lockfile, srv].each do |io|
            next unless io
            fd = io.fileno.to_i
            opts[fd] = fd
          end
        end

        Kernel.exec(*args)
      end

      def run
        init
        work
      ensure
        cleanup
      end

    private

      def init
        trap('TERM') { @run = false }
        trap('INT')  { @run = false }

        info "starting skylight daemon"
        @collector.spawn
      end

      def work
        @socks << @server

        next_sanity_check_at = Time.now.to_i + sanity_check_int

        trace "starting IO loop"
        begin
          # Wait for something to do
          r, _, _ = IO.select(@socks, [], [], timeout)

          if r
            r.each do |sock|
              if sock == @server
                # If the server socket, accept
                # the incoming connection
                if client = accept
                  connect(client)
                end
              else
                # Client socket, lookup the associated connection
                # state machine.
                unless conn = @connections[sock]
                  # No associated connection, weird.. bail
                  client_close(sock)
                  next
                end

                begin
                  # Pop em while we got em
                  while msg = conn.read
                    handle(msg)
                  end
                rescue SystemCallError, EOFError
                  client_close(sock)
                rescue IpcProtoError => e
                  error "Server#work - IPC protocol exception: %s", e.message
                  client_close(sock)
                end
              end
            end
          end

          now = Time.now.to_i

          if next_sanity_check_at <= now
            next_sanity_check_at = now + sanity_check_int
            sanity_check
          end

        rescue SignalException => e
          error "Did not handle: #{e.class}"
          @run = false
        rescue WorkerStateError => e
          info "#{e.message} - shutting down"
          @run = false
        rescue Exception => e
          error "Loop exception: %s (%s)", e.message, e.class
          puts e.backtrace
          return false
        rescue Object => o
          error "Unknown object thrown: `%s`", o.to_s
          return false
        end while @run

        true # Successful return
      end

      # Handles an incoming message. Will be instances from
      # the Messages namespace
      def handle(msg)
        case msg
        when nil
          return
        when Messages::Hello
          if msg.newer?
            info "newer version of agent deployed - restarting; curr=%s; new=%s", VERSION, msg.version
            reload(msg)
          end
        when Messages::Trace
          @collector.submit(msg)
        when :unknown
          debug "Got unknown message"
        else
          debug "GOT: %s", msg
        end
      end

      def reload(hello)
      end

      def accept
        @server.accept_nonblock
      rescue Errno::EWOULDBLOCK, Errno::EAGAIN, Errno::ECONNABORTED
      end

      def connect(sock)
        trace "client accepted"
        @socks << sock
        @connections[sock] = Connection.new(sock)
      end

      def cleanup
        # Neither the lockfile nor the sockfile are deleted. There is no atomic
        # way to delete the lockfile in the case that somebody manually removed
        # the lockfile and a new agent process created a new one.
        #
        # The sockfile is left around as well in order to provide a hint to
        # rails processes that the agent is dead. That way, when they attempt
        # to connect to the unix domain socket, it will faill quickly.
        close
        @lockfile.close
      end

      def close
        @server.close if @server
        @connections.keys.each do |sock|
          client_close(sock)
        end
      end

      def client_close(sock)
        @connections.delete(sock)
        @socks.delete(sock)
        sock.close rescue nil
      end

      def sockfile
        "#{sockfile_path}/skylight-#{pid}.sock"
      end

      def sockfile?
        File.exist?(sockfile)
      end

      def cleanup_curr_sockfile
        File.unlink(sockfile) rescue nil
      end

      # def cleanup_sockfiles
      #   Dir["#{sockfile_path}/skylight-*.sock"].each do |f|
      #     next if File.expand_path(f) == 
      #     File.unlink(f) rescue nil
      #   end
      # end

      def sanity_check
        if !File.exist?(lockfile_path)
          raise WorkerStateError, "lockfile gone"
        end

        pid = File.read(lockfile_path) rescue nil

        unless pid
          raise WorkerStateError, "could not read lockfile"
        end

        unless pid == Process.pid.to_s
          raise WorkerStateError, "lockfile points to different process"
        end

        unless sockfile?
          raise WorkerStateError, "sockfile gone"
        end
      end

      def sanity_check_int
        1
      end

      def timeout
        1
      end
    end
  end
end
