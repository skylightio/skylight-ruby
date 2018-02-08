require 'uri'
require 'logger'
require 'net/http'
require 'fileutils'
require 'digest/sha2'
require 'skylight/util/ssl'
require 'skylight/core/util/proxy'

# Used from extconf.rb
module Skylight
  # Utility class for fetching the native extension from a URL
  class NativeExtFetcher
    BASE_URL = "https://s3.amazonaws.com/skylight-agent-packages/skylight-native"
    MAX_REDIRECTS = 5
    MAX_RETRIES = 3

    include FileUtils

    class FetchError < StandardError; end

    # Creates a new fetcher and fetches
    # @param opts [Hash]
    def self.fetch(opts = {})
      fetcher = new(
        opts[:source] || BASE_URL,
        opts[:target],
        opts[:version],
        opts[:checksum],
        opts[:arch],
        opts[:required],
        opts[:platform],
        opts[:logger] || Logger.new(STDOUT))

      fetcher.fetch
    end

    # @param source [String] the base url to download from
    # @param target [String] file to download as
    # @param version [String] version to download
    # @param checksum [String] checksum of the archive
    # @param arch [String] platform architecture, e.g. `linux-x86_64`
    # @param required [Boolean] whether the download is required to be successful
    # @param platform
    # @param log [Logger]
    def initialize(source, target, version, checksum, arch, required, platform, log)
      raise "source required" unless source
      raise "target required" unless target
      raise "checksum required" unless checksum
      raise "arch required" unless arch

      @source = source
      @target = target
      @version = version
      @checksum = checksum
      @required = required
      @platform = platform
      @arch = arch
      @log = log
    end

    # Fetch the native extension, verify, inflate, and save (if applicable)
    #
    # @return [String] the inflated archive
    def fetch
      log "fetching native ext; curr-platform=#{@platform}; " \
        "requested-arch=#{@arch}; version=#{@version}"

      tar_gz = "#{@target}/#{basename}"

      unless sha2 = fetch_native_ext(source_uri, tar_gz, MAX_RETRIES, MAX_REDIRECTS)
        maybe_raise "could not fetch native extension"
        return
      end

      unless verify_checksum(sha2)
        maybe_raise "could not verify checksum"
        return
      end

      Dir.chdir File.dirname(tar_gz) do
        system "tar xzvf #{tar_gz}"
      end

      true
    ensure
      rm_f tar_gz if tar_gz
    end

    def fetch_native_ext(uri, out, attempts, redirects)
      redirects.times do |i|
        # Ensure the location is available
        mkdir_p File.dirname(out)
        rm_f out

        remaining_attempts = attempts

        log "attempting to fetch from remote; uri=#{uri}"

        begin
          host, port, use_ssl, path = deconstruct_uri(uri)

          File.open out, 'w' do |f|
            res, extra = http_get(host, port, use_ssl, path, f)

            case res
            when :success
              log "successfully downloaded native ext; out=#{out}"
              return extra
            when :redirect
              log "fetching native ext; uri=#{uri}; redirected=#{res}"
              uri = extra

              next
            end
          end
        rescue => e
          remaining_attempts -= 1

          error "failed to fetch native extension; uri=#{uri}; msg=#{e.message}; remaining-attempts=#{remaining_attempts}", e

          if remaining_attempts > 0
            sleep 2
            retry
          end

          return
        end
      end

      log "exceeded max redirects"
      return
    end

    # Get with `Net::HTTP`
    #
    # @param host [String] host for `Net::HTTP` request
    # @param port [String,Integer] port for `Net::HTTP` request
    # @param use_ssl [Boolean] whether SSL should be used for this request
    # @param path [String] the path to request
    # @param out [IO]
    #
    # If `ENV['HTTP_PROXY']` is set, it will be used as a proxy for this request.
    def http_get(host, port, use_ssl, path, out)
      if http_proxy = Core::Util::Proxy.detect_url(ENV)
        log "connecting with proxy: #{http_proxy}"
        uri = URI.parse(http_proxy)
        p_host, p_port = uri.host, uri.port
        p_user, p_pass = uri.userinfo.split(/:/) if uri.userinfo
      end

      opts = {}
      opts[:use_ssl] = use_ssl

      if use_ssl
        opts[:ca_file] = Util::SSL.ca_cert_file_or_default
      end

      Net::HTTP.start(host, port, p_host, p_port, p_user, p_pass, use_ssl: use_ssl) do |http|
        http.request_get path do |resp|
          case resp
          when Net::HTTPSuccess
            digest = Digest::SHA2.new

            resp.read_body do |chunk|
              digest << chunk
              out.write chunk
            end

            return [ :success, digest.hexdigest ]
          when Net::HTTPRedirection
            unless location = resp['location']
              raise "received redirect but no location"
            end

            return [ :redirect, location ]
          else
            raise "received HTTP status code #{resp.code}"
          end
        end
      end
    end

    # Verify the checksum of the archive
    #
    # @param actual [String]
    # @return [Boolean] whether the checksum matches
    def verify_checksum(actual)
      unless @checksum == actual
        log "checksum mismatch; expected=#{@checksum}; actual=#{actual}"
        return false
      end

      true
    rescue Exception => e
      error "failed to read skylight agent archive; e=#{e.message}"
      false
    end

    def basename
      "skylight_#{@arch}.tar.gz"
    end

    # The url that will be fetched
    #
    # @return String
    def source_uri
      "#{@source}/#{@version}/#{basename}"
    end

    # Split the uri string into its component parts
    #
    # @param uri [String] the uri
    # @return [Array<String>] the host, port, scheme, and request_uri
    def deconstruct_uri(uri)
      uri = URI(uri)
      [ uri.host, uri.port, uri.scheme == 'https', uri.request_uri ]
    end

    # Log an error and raise if `required` is `true`
    #
    # @param err [String]
    # @return [void]
    def maybe_raise(err)
      error err

      if @required
        raise err
      end
    end

    # Log an `info` to the `logger`
    #
    # @param msg [String]
    # @return [void]
    def log(msg)
      msg = "[SKYLIGHT] #{msg}"
      @log.info msg
    end

    # Log an `error` to the `logger`
    #
    # @param msg [String]
    # @param e [Exception] the exception associated with the error
    # @return [void]
    def error(msg, e=nil)
      msg = "[SKYLIGHT] #{msg}"
      msg << "\n#{e.backtrace.join("\n")}" if e
      @log.error msg
    end
  end
end
