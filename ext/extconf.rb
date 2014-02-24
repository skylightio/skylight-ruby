require 'mkmf'
require 'rbconfig'
require 'net/http'
require 'zlib'
require 'yaml'
require 'digest/sha2'

require_relative '../lib/skylight/version.rb'

checksums = YAML.load_file("checksums.yml")

rust_version = "dc29745"

arch = RbConfig::CONFIG["arch"]

url = "https://github.com/skylightio/skylight-rust/releases/download/#{rust_version}/libskylight.#{arch}.a.gz"

required = ENV.key?("SKYLIGHT_REQUIRED")

unless File.exist?("libskylight.a")
  puts "[SKYLIGHT] [#{Skylight::VERSION}] Downloading from #{url.inspect}"
  location = nil
  uri = URI.parse(url)

  begin
    Net::HTTP.start("github.com", 443, use_ssl: true) do |http|
      response = http.get(uri.request_uri)
      location = response["Location"]
    end

    if location
      archive = nil

      uri = URI(location)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        response = http.get(uri.request_uri)
        archive = response.body
      end
    else
      raise "No location returned" if required
      missing_a = true
    end
  rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
       Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError
    raise if required
    missing_a = true
  end

  unless missing_a
    expected_checksum = checksums[arch]
    actual_checksum = Digest::SHA2.hexdigest(archive)

    if expected_checksum == actual_checksum
      inflater, dest = Zlib::Inflate.new(32 + Zlib::MAX_WBITS), ""
      dest << inflater.inflate(archive)
      inflater.close

      File.open("libskylight.a", "w") { |file| file.write dest }
    else
      raise "Checksum mismatched; expected=#{expected_checksum.inspect}; actual=#{actual_checksum.inspect}" if required
      missing_a = true
    end
  end
end

if missing_a
  puts "[SKYLIGHT] [#{Skylight::VERSION}] Could not download Skylight native code from Github; version=#{rust_version.inspect}; arch=#{arch.inspect}"

  exit 1 if required

  File.open("Makefile", "w") do |file|
    file.puts "default:"
    file.puts "install:"
  end
else
  have_header 'dlfcn.h'

  find_library("skylight", "factory", ".")

  $CFLAGS << " -Werror"
  if RbConfig::CONFIG["arch"] =~ /darwin(\d+)?/
    $LDFLAGS << " -lpthread"
  else
    $LDFLAGS << " -Wl,--version-script=skylight.map"
    $LDFLAGS << " -lrt -ldl -lm -lpthread"
  end

  CONFIG['warnflags'].gsub!('-Wdeclaration-after-statement', '')

  create_makefile 'skylight_native', '.'
end
