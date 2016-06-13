require 'uri'
require 'logger'
require 'net/http'
require 'fileutils'
require 'digest/sha2'
require 'skylight/util/ssl'
require 'skylight/util/proxy'

# Used from extconf.rb
module Skylight
  module Util
    class NativeExtFetcher
      BASE_URL = "https://s3.amazonaws.com/skylight-agent-packages/skylight-native"
      MAX_REDIRECTS = 5
      MAX_RETRIES = 3

      include FileUtils

      class FetchError < StandardError; end

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

      def http_get(host, port, use_ssl, path, out)
        if http_proxy = Proxy.detect_url(ENV)
          log "connecting with proxy: #{http_proxy}"
          uri = URI.parse(http_proxy)
          p_host, p_port = uri.host, uri.port
          p_user, p_pass = uri.userinfo.split(/:/) if uri.userinfo
        end

        opts = {}
        opts[:use_ssl] = use_ssl

        if use_ssl
          opts[:ca_file] = SSL.ca_cert_file_or_default
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

      def source_uri
        "#{@source}/#{@version}/#{basename}"
      end

      def deconstruct_uri(uri)
        uri = URI(uri)
        [ uri.host, uri.port, uri.scheme == 'https', uri.request_uri ]
      end

      def maybe_raise(err)
        error err

        if @required
          raise err
        end
      end

      def log(msg)
        msg = "[SKYLIGHT] #{msg}"
        @log.info msg
      end

      def error(msg, e=nil)
        msg = "[SKYLIGHT] #{msg}"
        msg << "\n#{e.backtrace.join("\n")}" if e
        @log.error msg
      end
    end
  end
end
