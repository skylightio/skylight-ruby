require 'openssl'
require 'skylight/core/util/deploy'
require 'skylight/core/util/hostname'
require 'skylight/core/util/platform'
require 'skylight/core/util/ssl'

module Skylight
  class Config < Core::Config

    def self.env_to_key
      @env_to_key ||= super.merge(
        # == Authentication ==
        'AUTHENTICATION' => :authentication,

        # == App settings ==
        'ROOT'          => :root,
        'HOSTNAME'      => :hostname,
        'SESSION_TOKEN' => :session_token,

        # == Deploy settings ==
        'DEPLOY_ID'          => :'deploy.id',
        'DEPLOY_GIT_SHA'     => :'deploy.git_sha',
        'DEPLOY_DESCRIPTION' => :'deploy.description',

        # == Sql Lexer ==
        'USE_OLD_SQL_LEXER' => :use_old_sql_lexer,

        # == Instrumenter ==
        "IGNORED_ENDPOINT" => :ignored_endpoint,
        "IGNORED_ENDPOINTS" => :ignored_endpoints,

        # == Skylight Remote ==
        "AUTH_URL"                     => :auth_url,
        "APP_CREATE_URL"               => :app_create_url,
        "VALIDATION_URL"               => :validation_url,
        "AUTH_HTTP_DEFLATE"            => :auth_http_deflate,
        "AUTH_HTTP_CONNECT_TIMEOUT"    => :auth_http_connect_timeout,
        "AUTH_HTTP_READ_TIMEOUT"       => :auth_http_read_timeout,
        "REPORT_URL"                   => :report_url,
        "REPORT_HTTP_DEFLATE"          => :report_http_deflate,
        "REPORT_HTTP_CONNECT_TIMEOUT"  => :report_http_connect_timeout,
        "REPORT_HTTP_READ_TIMEOUT"     => :report_http_read_timeout,

        # == Native agent settings ==
        #
        "LAZY_START"                   => :'daemon.lazy_start',
        "DAEMON_EXEC_PATH"             => :'daemon.exec_path',
        "DAEMON_LIB_PATH"              => :'daemon.lib_path',
        "PIDFILE_PATH"                 => :'daemon.pidfile_path',
        "SOCKDIR_PATH"                 => :'daemon.sockdir_path',
        "BATCH_QUEUE_DEPTH"            => :'daemon.batch_queue_depth',
        "BATCH_SAMPLE_SIZE"            => :'daemon.batch_sample_size',
        "BATCH_FLUSH_INTERVAL"         => :'daemon.batch_flush_interval',
        "DAEMON_TICK_INTERVAL"         => :'daemon.tick_interval',
        "DAEMON_SANITY_CHECK_INTERVAL" => :'daemon.sanity_check_interval',
        "DAEMON_INACTIVITY_TIMEOUT"    => :'daemon.inactivity_timeout',
        "CLIENT_MAX_TRIES"             => :'daemon.max_connect_tries',
        "CLIENT_CONN_TRY_WIN"          => :'daemon.connect_try_window',
        "MAX_PRESPAWN_JITTER"          => :'daemon.max_prespawn_jitter',
        "DAEMON_WAIT_TIMEOUT"          => :'daemon.wait_timeout',
        "CLIENT_CHECK_INTERVAL"        => :'daemon.client_check_interval',
        "CLIENT_QUEUE_DEPTH"           => :'daemon.client_queue_depth',
        "CLIENT_WRITE_TIMEOUT"         => :'daemon.client_write_timeout',
        "SSL_CERT_PATH"                => :'daemon.ssl_cert_path',
        "SSL_CERT_DIR"                 => :'daemon.ssl_cert_dir',

        # == Legacy env vars ==
        #
        'AGENT_LOCKFILE'      => :'agent.lockfile',
        'AGENT_SOCKFILE_PATH' => :'agent.sockfile_path'
      )
    end

    # Default values for Skylight configuration keys
    def self.default_values
      @default_values ||= begin
        ret = super.merge(
          :auth_url             => 'https://auth.skylight.io/agent',
          :app_create_url       => 'https://www.skylight.io/apps',
          :validation_url       => 'https://auth.skylight.io/agent/config',
          :'daemon.lazy_start'  => true,
          :hostname             => Core::Util::Hostname.default_hostname,
          :use_old_sql_lexer    => false
        )

        if Core::Util::Platform::OS != 'darwin'
          ret[:'daemon.ssl_cert_path'] = Core::Util::SSL.ca_cert_file_or_default
          ret[:'daemon.ssl_cert_dir'] = Core::Util::SSL.ca_cert_dir
        end

        if Skylight.native?
          native_path = Skylight.libskylight_path

          ret[:'daemon.lib_path'] = native_path
          ret[:'daemon.exec_path'] = File.join(native_path, 'skylightd')
        end

        ret
      end
    end

    def self.required_keys
      @required_keys ||= super.merge(
        authentication: "authentication token",
        hostname:       "server hostname",
        auth_url:       "authentication url",
        validation_url: "config validation url"
      )
    end

    def self.native_env_keys
      @native_env_keys ||= super + [
        :version,
        :root,
        :hostname,
        :deploy_id,
        :session_token,
        :auth_url,
        :auth_http_deflate,
        :auth_http_connect_timeout,
        :auth_http_read_timeout,
        :report_url,
        :report_http_deflate,
        :report_http_connect_timeout,
        :report_http_read_timeout,
        :'daemon.lazy_start',
        :'daemon.exec_path',
        :'daemon.lib_path',
        :'daemon.pidfile_path',
        :'daemon.sockdir_path',
        :'daemon.batch_queue_depth',
        :'daemon.batch_sample_size',
        :'daemon.batch_flush_interval',
        :'daemon.tick_interval',
        :'daemon.sanity_check_interval',
        :'daemon.inactivity_timeout',
        :'daemon.max_connect_tries',
        :'daemon.connect_try_window',
        :'daemon.max_prespawn_jitter',
        :'daemon.wait_timeout',
        :'daemon.client_check_interval',
        :'daemon.client_queue_depth',
        :'daemon.client_write_timeout',
        :'daemon.ssl_cert_path',
        :'daemon.ssl_cert_dir'
      ]
    end

    def self.legacy_keys
      @legacy_keys ||= super.merge(
        :'agent.sockfile_path' => :'daemon.sockdir_path',
        :'agent.lockfile'      => :'daemon.pidfile_path'
      )
    end

    def self.validators
      @validators ||= super.merge(
        :'agent.interval' => [lambda { |v, c| Integer === v && v > 0 }, "must be an integer greater than 0"]
      )
    end

    # @api private
    def api
      @api ||= Api.new(self)
    end

    # @api private
    def validate!
      super

      # TODO: Move this out of the validate! method: https://github.com/tildeio/direwolf-agent/issues/273
      # FIXME: Why not set the sockdir_path and pidfile_path explicitly?
      # That way we don't have to keep this in sync with the Rust repo.
      sockdir_path = File.expand_path(self[:'daemon.sockdir_path'] || '.', root)
      pidfile_path = File.expand_path(self[:'daemon.pidfile_path'] || 'skylight.pid', sockdir_path)

      check_file_permissions(pidfile_path, "daemon.pidfile_path or daemon.sockdir_path")
      check_sockdir_permissions(sockdir_path)

      true
    end

    def validate_with_server
      res = api.validate_config

      unless res.token_valid?
        warn("Invalid authentication token")
        return false
      end

      if res.is_error_response?
        warn("Unable to reach server for config validation")
      end

      unless res.config_valid?
        warn("Invalid configuration") unless res.is_error_response?
        if errors = res.validation_errors
          errors.each do |k,v|
            warn("  #{k} #{v}")
          end
        end

        corrected_config = res.corrected_config
        unless corrected_config
          # Use defaults if no corrected config is available. This will happen if the request failed.
          corrected_config = Hash[self.class.server_validated_keys.map{|k| [k, [k]] }]
        end

        config_to_update = corrected_config.select{|k,v| get(k) != v }
        unless config_to_update.empty?
          info("Updating config values:")
          config_to_update.each do |k,v|
            info("  setting #{k} to #{v}")

            # This is a weird way to handle priorities
            # See https://github.com/tildeio/direwolf-agent/issues/275
            k = "#{environment}.#{k}" if environment

            set(k, v)
          end
        end
      end

      return true
    end

    def check_sockdir_permissions(sockdir_path)
      # Try to make the directory, don't blow up if we can't. Our writable? check will fail later.
      FileUtils.mkdir_p sockdir_path rescue nil

      unless FileTest.writable?(sockdir_path)
        raise Core::ConfigError, "Directory `#{sockdir_path}` is not writable. Please set daemon.sockdir_path in your config to a writable path"
      end

      if check_nfs(sockdir_path)
        raise Core::ConfigError, "Directory `#{sockdir_path}` is an NFS mount and will not allow sockets. Please set daemon.sockdir_path in your config to a non-NFS path."
      end
    end

    def to_native_env
      ret = super

      ret << "SKYLIGHT_AUTHENTICATION" << authentication_with_deploy
      ret << "SKYLIGHT_VALIDATE_AUTHENTICATION" << "false"

      ret
    end

    def write(path)
      FileUtils.mkdir_p(File.dirname(path))

      File.open(path, 'w') do |f|
        f.puts <<-YAML
---
# The authentication token for the application.
authentication: #{self[:authentication]}
        YAML
      end
    end

    #
    #
    # ===== Helpers =====
    #
    #

    def authentication_with_deploy
      token = get(:authentication)

      if token && deploy
        deploy_str = deploy.to_query_string
        # A pipe should be a safe delimiter since it's not in the standard token
        # and is encoded by URI
        token += "|#{deploy_str}"
      end

      token
    end

    def deploy
      @deploy ||= Core::Util::Deploy.build(self)
    end

  private

    def check_nfs(path)
      # Should work on most *nix, though not on OS X
      `stat -f -L -c %T #{path} 2>&1`.strip == 'nfs'
    end

  end
end
