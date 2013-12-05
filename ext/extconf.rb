require 'mkmf'
require 'rbconfig'
require 'net/http'
require 'zlib'

unless RbConfig::CONFIG["arch"] == "x86_64-linux"
  puts "At the moment, Skylight only supports 64-bit linux"
  exit 1
end

location = nil

Net::HTTP.start("github.com", 443, use_ssl: true) do |http|
  uri = URI.parse("https://github.com/skylightio/skylight-rust/releases/download/v0.3.0-pre.1/libskylight-x86_64-linux.a.gz")
  response = http.get(uri.request_uri)
  location = response["Location"]
end

archive = nil

uri = URI(location)
Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
  response = http.get(uri.request_uri)
  archive = response.body
end

inflater, dest = Zlib::Inflate.new(32 + Zlib::MAX_WBITS), ""
inflater.inflate(archive) { |chunk| dest << chunk }

File.open("libskylight.a", "w") { |file| file.write dest }

have_header 'dlfcn.h'

find_library("skylight", "factory", ".")

$LDFLAGS << " -Wl,-no-export-dynamic,--version-script=skylight.map"
$LDFLAGS << " -lrt -ldl -lm -lpthread"

CONFIG['warnflags'].gsub!('-Wdeclaration-after-statement', '')

create_makefile 'skylight_native', '.'
