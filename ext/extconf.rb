require 'mkmf'
require 'rbconfig'
require 'net/http'
require 'zlib'
require 'yaml'
require 'digest/sha2'

checksums = YAML.load_file("checksums.yml")

unless File.exist?("libskylight.a")
  unless RbConfig::CONFIG["arch"] == "x86_64-linux"
    puts "[SKYLIGHT] At the moment, Skylight only supports 64-bit linux"
    File.open("Makefile", "w") { |f| f.puts "hello:\ninstall:" }

    exit 1
  end

  location = nil

  begin
    Net::HTTP.start("github.com", 443, use_ssl: true) do |http|
      uri = URI.parse("https://github.com/skylightio/skylight-rust/releases/download/v0.3.0-pre.1/libskylight-x86_64-linux.a.gz")
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
      missing_a = true
    end
  rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
       Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError
    missing_a = true
  end

  unless missing_a
    inflater, dest = Zlib::Inflate.new(32 + Zlib::MAX_WBITS), ""
    dest << inflater.inflate(archive)
    inflater.close

    expected_checksum = checksums[RbConfig::CONFIG["arch"]]
    actual_checksum = Digest::SHA2.hexdigest(dest)

    if expected_checksum == actual_checksum
      File.open("libskylight.a", "w") { |file| file.write dest }
    else
      missing_a = true
    end
  end
end

if missing_a
  puts "[SKYLIGHT] Could not download Skylight native code from Github"

  exit 1 if ENV.key?("SKYLIGHT_REQUIRED")

  File.open("Makefile", "w") do |file|
    file.puts "default:"
  end
else
  have_header 'dlfcn.h'

  find_library("skylight", "factory", ".")

  if RbConfig::CONFIG["arch"] =~ /darwin(\d+)?/
    $LDFLAGS << " -lpthread"
  else
    $LDFLAGS << " -Wl,--version-script=skylight.map"
    $LDFLAGS << " -lrt -ldl -lm -lpthread"
  end

  CONFIG['warnflags'].gsub!('-Wdeclaration-after-statement', '')

  create_makefile 'skylight_native', '.'
end
