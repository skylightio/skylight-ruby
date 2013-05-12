require 'socket'
require 'rbconfig'

module Skylight
  module Worker
    class Standalone
      include Util::Logging

      attr_reader :pid

      def initialize
        @pid    = nil
        @srv    = nil
        @conns  = nil
        @parent = Messages::Pid.new(Process.pid)
        spawn
      end

      def submit(data)
        # stuff
      end

    private

      # Handle exceptions from file opening here
      def spawn
        check_permissions

        begin
          if f = maybe_acquire_lock
            trace "standalone process lock acquired"
            @pid = spawn_worker(f)
          else
            trace "standalone process lock failed"
            @pid = read_lockfile
          end

          # Try reading the pid from the lockfile
          if @pid
            # Check if the sockfile has been created yet
            if sockfile?
              if sock = connect
                @conns = [sock]
                sock.write(@parent.to_bytes)
                return
              end
            end
          end

        ensure
          if f
            trace "closing lockfile"
            f.close rescue nil
          end
        end # while true

        # TMP
        Process.wait(@pid)
      end

      def connect
        UNIXSocket.new(sockfile) rescue nil
      end

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

          # Track the current pid
          # @pid = Process.pid

          # begin
          #   # Cleanup old sockfiles
          #   cleanup_sockfiles

          #   # Open the new socket
          #   @srv = create_server

          #   # Write the lockfile
          #   write_lockfile(lockfile, pid)

          #   # Start the work loop
          #   work

          # ensure
          #   # Cleanup the current sockfile
          #   cleanup_curr_sockfile

          #   # Clear the pid file
          #   File.unlink lockfile rescue nil

          #   # Release the file lock
          #   lockfile.close
          # end
        end
      ensure
        lockfile.close rescue nil
      end

      def work
        begin
          r, _, _ = IO.select([@srv], [], [], 1)

          if r
            s = r[0].accept_nonblock
            p s
          end
        rescue Exception => e
          error e.message
        end while true # TODO: better exit condition
      end

      def check_permissions
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

      def write_lockfile(file, pid)
        file.truncate(0)
        file.write(pid.to_s)
        file.flush
      end



      def cleanup_curr_sockfile
        File.unlink(sockfile) rescue nil
      end

      def create_server
        UNIXServer.new sockfile
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
