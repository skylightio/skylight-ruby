require 'mkmf'
require 'yaml'
require 'logger'

# Must require 'rubygems/platform' vs. just requiring 'rubygems' to avoid a
# stack overflow bug on ruby 1.9.2.
require 'rubygems/platform'

class MultiIO
  def initialize(*targets)
     @targets = targets
  end

  def write(*args)
    @targets.each {|t| t.write(*args)}
  end

  def close
    @targets.each(&:close)
  end
end

log_file = File.open("install.log", "a")
LOG = Logger.new(MultiIO.new(STDOUT, log_file))

SKYLIGHT_REQUIRED = ENV.key?("SKYLIGHT_REQUIRED") && ENV['SKYLIGHT_REQUIRED'] !~ /^false$/i

require_relative '../lib/skylight/version'
require_relative '../lib/skylight/util/native_ext_fetcher'

include Skylight::Util

# Handles terminating in the case of a failure. If we have a bug, we do not
# want to break our customer's deploy, but extconf.rb requires a Makefile to be
# present upon a successful exit. To satisfy this requirement, we create a
# dummy Makefile.
def fail(msg, type=:error)
  LOG.send type, msg

  if SKYLIGHT_REQUIRED
    exit 1
  else
    File.open("Makefile", "w") do |file|
      file.puts "default:"
      file.puts "install:"
    end

    exit
  end
end

libskylight_a = File.expand_path('../libskylight.a', __FILE__)
libskylight_yml = File.expand_path('../libskylight.yml', __FILE__)

unless File.exist?(libskylight_a)
  # Ensure that libskylight.yml is present and load it
  unless File.exist?(libskylight_yml)
    fail "`#{libskylight_yml}` does not exist"
  end

  unless libskylight_info = YAML.load_file(libskylight_yml)
    fail "`#{libskylight_yml}` does not contain data"
  end

  unless version = libskylight_info["version"]
    fail "libskylight version missing from `#{libskylight_yml}`"
  end

  unless checksums = libskylight_info["checksums"]
    fail "libskylight checksums missing from `#{libskylight_yml}`"
  end

  platform = Gem::Platform.local
  arch = "#{platform.os}-#{platform.cpu}"

  unless checksum = checksums[arch]
    fail "no checksum entry for requested architecture -- " \
             "this probably means the requested architecture is not supported; " \
             "arch=#{arch}; available=#{checksums.keys}", :info
  end

  begin
    res = NativeExtFetcher.fetch(
      version: version,
      target: libskylight_a,
      checksum: checksum,
      arch: arch,
      required: SKYLIGHT_REQUIRED,
      logger: LOG)

    unless res
      fail "could not fetch archive -- aborting skylight native extension build"
    end
  rescue => e
    fail "unable to fetch native extension; msg=#{e.message}\n#{e.backtrace.join("\n")}"
  end
end

#
#
# ===== By this point, libskylight.a is present =====
#
#

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
