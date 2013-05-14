require 'socket'

module Skylight
  module Worker
    class Server

      include Util::Logging

      attr_reader :pid, :lockfile_path, :sockfile_path

      def initialize(lockfile, lockfile_path, sockfile_path)
        @pid           = Process.pid
        @run           = true
        @socks         = []
        @server        = nil
        @lockfile      = lockfile
        @connections   = {}
        @lockfile_path = lockfile_path
        @sockfile_path = sockfile_path
      end

      def run
        init
        work
      ensure
        cleanup
      end

    private

      def init
        # Start by cleaning up old sockfiles
        cleanup_sockfiles

        # Create the UNIX domain socket
        bind

        # Write the PID file
        write_pid

        trap('TERM') { @run = false }
        trap('INT')  { @run = false }
      end

      def work
        @socks << @server

        next_sanity_check_at = Time.now.to_i + sanity_check_int

        # IO loop
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
                  sock.close rescue nil
                  next
                end

                begin
                  # Pop em while we got em
                  while msg = conn.read
                    handle(msg)
                  end
                rescue SystemCallError
                  @socks.delete(sock)
                  sock.close rescue nil
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
        rescue Exception => e
          error "Loop exception: %s", e.message
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
        when Messages::Pid
          debug "Got pid message: %s", msg
        when :unknown
          debug "Got unknown message"
        else
          debug "GOT: %s", msg
        end
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
        cleanup_curr_sockfile
        close
        cleanup_lockfile
        @lockfile.close
      end

      def bind
        @server ||= UNIXServer.new sockfile
      end

      def close
        @server.close if @server
      end

      def write_pid
        @lockfile.write(pid.to_s)
        @lockfile.flush
      end

      def sockfile
        "#{sockfile_path}/skylight-#{pid}.sock"
      end

      def sockfile?
        File.exist?(sockfile)
      end

      def cleanup_lockfile
        File.unlink(lockfile_path) rescue nil
      end

      def cleanup_curr_sockfile
        File.unlink(sockfile) rescue nil
      end

      def cleanup_sockfiles
        Dir["#{sockfile_path}/skylight-*.sock"].each do |sockfile|
          File.unlink(sockfile) rescue nil
        end
      end

      def sanity_check
        # TODO: implement
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
