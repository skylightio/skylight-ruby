require 'uri'
require 'logger'
require 'zlib'
require 'net/http'
require 'digest/sha2'

# Must require 'rubygems/platform' vs. just requiring 'rubygems' to avoid a
# stack overflow bug on ruby 1.9.2.
require 'rubygems/platform'

module Skylight
  module Util
    class NativeExtFetcher
      BASE_URL = "https://github.com/skylightio/skylight-rust/releases/download"
      MAX_REDIRECTS = 5
      MAX_RETRIES = 3

      class FetchError < StandardError; end

      def self.fetch(opts = {})
        fetcher = new(
          BASE_URL,
          opts[:target],
          opts[:version],
          opts[:checksum],
          opts[:arch],
          opts[:required],
          opts[:logger] || Logger.new(STDOUT))

        fetcher.fetch
      end

      def initialize(source, target, version, checksum, arch, required, log)
        raise "source required" unless source
        raise "checksum required" unless checksum
        raise "arch required" unless arch

        @source = source
        @target = target
        @version = version
        @checksum = checksum
        @required = required
        @arch = arch
        @log = log
      end

      def fetch
        log "fetching native ext; curr-platform=#{Gem::Platform.local.to_s}; " \
          "requested-arch=#{@arch}; version=#{@version}"

        unless gziped = fetch_native_ext(source_uri, MAX_RETRIES, MAX_REDIRECTS)
          maybe_raise "could not fetch native extension"
          return
        end

        unless verify_checksum(gziped)
          maybe_raise "could not verify checksum"
          return
        end

        archive = inflate(gziped)

        if @target
          File.open @target, 'w' do |f|
            f.write(archive)
          end
        end

        archive
      end

      def self.http_get(host, port, use_ssl, path)
        Net::HTTP.start(host, port, use_ssl: use_ssl) do |http|
          case response = http.get(path)
          when Net::HTTPSuccess
            return [ :success, response.body ]
          when Net::HTTPRedirection
            unless location = response['location']
              raise "received redirect but no location"
            end

            return [ :redirect, location ]
          else
            raise "received HTTP status code #{response.code}"
          end
        end
      end

      def fetch_native_ext(uri, attempts, redirects)
        redirects.times do |i|
          remaining_attempts = attempts

          log "attempting to fetch from remote; uri=#{uri}"

          begin
            host, port, use_ssl, path = deconstruct_uri(uri)

            status, body = NativeExtFetcher.http_get(host, port, use_ssl, path)

            case status
            when :success
              if body
                log "successfully downloaded native ext; body=#{body.bytesize}bytes"
              else
                log "response did not contain a body"
              end

              return body
            when :redirect
              log "fetching native ext; uri=#{uri}; redirected=#{body}"
              uri = body

              next
            else
              raise "received unknown return; status=#{status}; body=#{body}"
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

      def verify_checksum(archive)
        expected = @checksum
        actual = Digest::SHA2.hexdigest(archive)

        unless expected == actual
          log "checksum mismatch; expected=#{expected}; actual=#{actual}"
          return false
        end

        true
      end

      def inflate(archive)
        inflater = Zlib::Inflate.new(32 + Zlib::MAX_WBITS)
        inflated = inflater.inflate(archive)
        inflater.close
        inflated
      end

      def source_uri
        "#{@source}/#{@version}/libskylight.#{@version}.#{@arch}.a.gz"
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
