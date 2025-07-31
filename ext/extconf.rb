require "rbconfig"
require "mkmf"
require "logger"
require "fileutils"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "skylight/native_ext_fetcher"
require "skylight/util/platform"

GLIBC_MIN = 2.23
GLIBC_V4_MIN = 2.15
LIBSKYLIGHT_INFO = {
  "version" => "6.0.0-beta-ec1a887",
  "checksums" => {
    "x86-linux" => "0690d63cb7e249e3d74ad66a86bd886d75fb98650e3e2b029345c9b69d0931b2",
    "x86_64-linux" => "dc97213f8f2aa86278dd8d239db3253ecd95d5daaafa5e825d8dfffa52033177",
    "x86_64-linux-musl" => "963fc2515e3d91b80e2066d28c60ceabf40b88eec976eefa9c57f6be02e75b82",
    "x86_64-darwin" => "79c16cfe98a5c0088175df8936eeeb46ee13fec2c9ecb0294d2622cb3c838666",
    "x86_64-freebsd" => "be2e6d29f343a4c3dc90fc7d4a945fca67eaa062d35bcbca32ce130b022a2ba1",
    "aarch64-linux" => "a3e5c72bbed189138c4350884cb59420deb9b68d0337340b6c2a7e4154e8d41a",
    "aarch64-linux-musl" => "58282d7a638c8144aaee9ad5cb96ae667ea6f981a8ddbef566c8a618d7b82f8c",
    "aarch64-darwin" => "fc4135413cda6130610e7a9c72b2a7af3e9db37107839b0bce7929b2ba55264b"
  }.freeze
}.freeze

ldd_output =
  begin
    `ldd --version`
  rescue Errno::ENOENT
    nil
  end

if ldd_output =~ /GLIBC (\d+(\.\d+)+)/ && ($1.to_f < GLIBC_MIN)
  message = "glibc #{GLIBC_MIN}+ is required but you have #{$1} installed."
  message << "\nYou may be able to use Skylight v4 instead." if $1.to_f >= GLIBC_V4_MIN
  fail message
end

# Util allowing proxying writes to multiple location
class MultiIO
  def initialize(*targets)
    @targets = targets
  end

  def write(*args)
    @targets.each { |t| t.write(*args) }
  end

  def close
    @targets.each(&:close)
  end
end

include Skylight::Util

SKYLIGHT_INSTALL_LOG = File.expand_path("install.log", __dir__)
SKYLIGHT_REQUIRED = ENV.key?("SKYLIGHT_REQUIRED") && ENV.fetch("SKYLIGHT_REQUIRED", nil) !~ /^false$/i
SKYLIGHT_FETCH_LIB = !ENV.key?("SKYLIGHT_FETCH_LIB") || ENV.fetch("SKYLIGHT_FETCH_LIB", nil) !~ /^false$/i

# Directory where skylight.h exists
SKYLIGHT_HDR_PATH = ENV.fetch("SKYLIGHT_HDR_PATH") { ENV.fetch("SKYLIGHT_LIB_PATH", ".") }
SKYLIGHT_LIB_PATH =
  ENV.fetch("SKYLIGHT_LIB_PATH") { File.expand_path("../../lib/skylight/native/#{Platform.tuple}", __FILE__) }

SKYLIGHT_SOURCE_URL = ENV.fetch("SKYLIGHT_SOURCE_URL", nil)
SKYLIGHT_VERSION = ENV.fetch("SKYLIGHT_VERSION", nil)
SKYLIGHT_CHECKSUM = ENV.fetch("SKYLIGHT_CHECKSUM", nil)

SKYLIGHT_EXT_STRICT = ENV.key?("SKYLIGHT_EXT_STRICT") && ENV.fetch("SKYLIGHT_EXT_STRICT", nil) =~ /^true$/i

# Setup logger
LOG = Logger.new(MultiIO.new($stdout, File.open(SKYLIGHT_INSTALL_LOG, "a")))

# Handles terminating in the case of a failure. If we have a bug, we do not
# want to break our customer's deploy, but extconf.rb requires a Makefile to be
# present upon a successful exit. To satisfy this requirement, we create a
# dummy Makefile.
def fail(msg, type = :error)
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

# Check that Xcode license has been approved
# Based on Homebrew's implementation
# https://github.com/Homebrew/homebrew/blob/03708b016755847facc4f19a43ee9f7a44141ed7/Library/Homebrew/cmd/doctor.rb#L1183
# If the user installs Xcode-only, they have to approve the
# license or no "xc*" tool will work.

# stree-ignore
if Platform::OS == "darwin" && (`/usr/bin/xcrun clang 2>&1` =~ /license/ && !$CHILD_STATUS.success?)
  fail <<~MESSAGE
    You have not agreed to the Xcode license and so we are unable to build the native agent.
    To resolve this, you can agree to the license by opening Xcode.app or running:
        sudo xcodebuild -license
  MESSAGE
end

#
# === Setup paths
#
hdrpath = File.expand_path(SKYLIGHT_HDR_PATH)
libpath = File.expand_path(SKYLIGHT_LIB_PATH)
extconf = __FILE__
libskylight = File.expand_path("libskylight.#{Platform.libext}", libpath)
skylight_dlopen_h = File.expand_path("skylight_dlopen.h", hdrpath)
skylight_dlopen_c = File.expand_path("skylight_dlopen.c", hdrpath)

LOG.info "SKYLIGHT_HDR_PATH=#{hdrpath}; SKYLIGHT_LIB_PATH=#{libpath}"

LOG.info "file exists; path=#{libskylight}" if File.exist?(libskylight)
LOG.info "file exists; path=#{skylight_dlopen_c}" if File.exist?(skylight_dlopen_c)
LOG.info "file exists; path=#{skylight_dlopen_h}" if File.exist?(skylight_dlopen_h)

# If libskylight is not present, fetch it
if !File.exist?(libskylight) && !File.exist?(skylight_dlopen_c) && !File.exist?(skylight_dlopen_h)
  fail "libskylight.#{LIBEXT} not found -- remote download disabled; aborting install" unless SKYLIGHT_FETCH_LIB

  if (version = SKYLIGHT_VERSION)
    unless (checksum = SKYLIGHT_CHECKSUM)
      fail "no checksum provided when using custom version"
    end
  elsif (platform_info = LIBSKYLIGHT_INFO[Platform.tuple])
    unless (version = platform_info["version"])
      fail "libskylight version missing from `#{extconf}`; platform=#{Platform.tuple}"
    end

    unless (checksum = platform_info["checksum"])
      fail "checksum missing from `#{extconf}`; platform=#{Platform.tuple}"
    end
  else
    unless (version = LIBSKYLIGHT_INFO["version"])
      fail "libskylight version missing from `#{extconf}`"
    end

    unless (checksums = LIBSKYLIGHT_INFO["checksums"])
      fail "libskylight checksums missing from `#{extconf}`"
    end

    unless (checksum = checksums[Platform.tuple])
      fail "no checksum entry for requested architecture -- " \
             "this probably means the requested architecture is not supported; " \
             "platform=#{Platform.tuple}; available=#{checksums.keys}",
           :info
    end
  end

  begin
    res =
      Skylight::NativeExtFetcher.fetch(
        source: SKYLIGHT_SOURCE_URL,
        version: version,
        target: hdrpath,
        checksum: checksum,
        arch: Platform.tuple,
        required: SKYLIGHT_REQUIRED,
        platform: Platform.tuple,
        logger: LOG
      )

    fail "could not fetch archive -- aborting skylight native extension build" unless res

    # Move skylightd & libskylight to appropriate directory
    if hdrpath != libpath
      # Ensure the directory is present
      FileUtils.mkdir_p libpath

      # Move
      FileUtils.mv "#{hdrpath}/libskylight.#{Platform.libext}", "#{libpath}/libskylight.#{Platform.libext}", force: true

      FileUtils.mv "#{hdrpath}/skylightd", "#{libpath}/skylightd", force: true
    end
  rescue StandardError => e
    fail "unable to fetch native extension; msg=#{e.message}\n#{e.backtrace.join("\n")}"
  end
end

#
#
# ===== By this point, libskylight is present =====
#
#

def find_file(file, root = nil)
  path = File.expand_path(file, root || ".")

  fail "#{file} missing; path=#{root}" unless File.exist?(path)
end

$VPATH << libpath

# Where the ruby binding src is
SRC_PATH = File.expand_path(__dir__)

$srcs = Dir[File.expand_path("*.c", SRC_PATH)].map { |f| File.basename(f) }

# If the native agent support files were downloaded to a different directory,
# explicitly the file to the list of sources.
unless $srcs.include?("skylight_dlopen.c")
  $srcs << "skylight_dlopen.c" # From libskylight dist
end

# Make sure that the files are present
find_file "skylight_dlopen.h", hdrpath
find_file "skylight_dlopen.c", hdrpath
find_header "skylight_dlopen.h", hdrpath
fail "could not create Makefile; dlfcn.h missing" unless have_header "dlfcn.h"

# For escaping the GVL
unless have_func("rb_thread_call_without_gvl", "ruby/thread.h")
  abort "Ruby is unexpectedly missing rb_thread_call_without_gvl. This should not happen."
end

# Previous comment stated:
#   -Werror is needed for the fast thread local storage
#
# Despite this comment, everything appears to build fine without the flag on. Since this
#   flag can cause issues for some customers we're turning it off by default. However,
#   in development and CI, we still have the option of turning it back on to help catch
#   potential issues.
$CFLAGS << " -Werror" if SKYLIGHT_EXT_STRICT

checking_for "fast thread local storage" do
  if try_compile("__thread int foo;")
    $defs << "-DHAVE_FAST_TLS"
    true
  end
end

# Flag -std=c99 required for older build systems
$CFLAGS << " -std=c99 -Wall -fno-strict-aliasing"

# Allow stricter checks to be turned on for development or debugging
if SKYLIGHT_EXT_STRICT
  $CFLAGS << " -Wextra"

  # Enabling unused-parameter causes failures in Ruby 2.6+
  #   ruby/ruby.h:2186:35: error: unused parameter 'allow_transient'
  $CFLAGS << " -Wno-error=unused-parameter"
end

# TODO: Compute the relative path to the location
create_makefile "skylight_native", File.expand_path(__dir__) # or fail "could not create makefile"
