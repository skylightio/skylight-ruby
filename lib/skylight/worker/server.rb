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

        # IO loop
        begin
          r, _, _ = IO.select(@socks, [], [], timeout)

          if r
            r.each do |sock|
              if sock == @server
                if client = accept
                  connect(client)
                end
              else
                unless conn = @connections[sock]
                  # Connection missing, weird
                  next
                end

                begin
                  conn.read
                rescue EOFError
                  @socks.delete(sock)
                  sock.close rescue nil
                end
              end
            end
          end
        rescue SignalException => e
          error "Did not handle: #{e.class}"
          @run = false
        rescue Exception => e
          error e.message
          return false
        rescue Object => o
          error "Unknown object thrown: `%s`", o.to_s
          return false
        end while @run

        true # Successful return
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

      def timeout
        1
      end
    end
  end
end
