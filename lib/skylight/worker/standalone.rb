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
        @parent = Messages::Pid.new(Process.pid, VERSION)
        spawn
      end

      def submit(data)
        # stuff
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
                  @conns = [sock]
                  sock.write(@parent.to_bytes)
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
        end
      ensure
        lockfile.close rescue nil
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
