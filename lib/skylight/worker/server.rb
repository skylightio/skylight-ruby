require 'socket'

module Skylight
  module Worker
    class Server

      attr_reader :pid, :lockfile_path, :sockfile_path

      def initialize(lockfile, lockfile_path, sockfile_path)
        @pid           = Process.pid
        @server        = nil
        @lockfile      = lockfile
        @lockfile_path = lockfile_path
        @sockfile_path = sockfile_path
      end

      def run
        init

        3.times do
          puts "HELLO"
          sleep 1
        end

      ensure
        # Cleanup
        cleanup_curr_sockfile
        close
        cleanup_lockfile
        @lockfile.close
      end

    private

      def init
        # Start by cleaning up old sockfiles
        cleanup_sockfiles

        # Create the UNIX domain socket
        bind

        # Write the PID file
        write_pid
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
    end
  end
end
