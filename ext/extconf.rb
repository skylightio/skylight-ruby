require 'mkmf'
require 'rbconfig'
require 'net/http'
require 'zlib'

unless RbConfig::CONFIG["arch"] == "x86_64-linux"
  puts "At the moment, Skylight only supports 64-bit linux"
  exit 1
end

github = Net::HTTP.get_response(URI("https://github.com/skylightio/skylight-rust/releases/download/v0.3.0-pre.1/libskylight-x86_64-linux.a.gz"))
archive = Net::HTTP.get_response(URI(github["Location"])).body

inflater, dest = Zlib::Inflate.new(32 + Zlib::MAX_WBITS), ""
inflater.inflate(archive) { |chunk| dest << chunk }

File.write("libskylight.a", dest)

have_header 'dlfcn.h'

find_library("skylight", "factory", ".")

$LDFLAGS << " -Wl,-no-export-dynamic,--version-script=skylight.map"
$LDFLAGS << " -lrt -ldl -lm -lpthread"

CONFIG['warnflags'].gsub!('-Wdeclaration-after-statement', '')

create_makefile 'skylight_native', '.'
