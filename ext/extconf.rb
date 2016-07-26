require 'rbconfig'
require 'mkmf'
require 'yaml'
require 'logger'
require 'fileutils'

$:.unshift File.expand_path("../../lib", __FILE__)
require 'skylight/version'
require 'skylight/util/multi_io'
require 'skylight/util/native_ext_fetcher'
require 'skylight/util/platform'

include Skylight::Util

SKYLIGHT_INSTALL_LOG = File.expand_path("../install.log", __FILE__)
SKYLIGHT_REQUIRED   = ENV.key?("SKYLIGHT_REQUIRED") && ENV['SKYLIGHT_REQUIRED'] !~ /^false$/i
SKYLIGHT_FETCH_LIB  = !ENV.key?('SKYLIGHT_FETCH_LIB') || ENV['SKYLIGHT_FETCH_LIB'] !~ /^false$/i

# Directory where skylight.h exists
SKYLIGHT_HDR_PATH = ENV['SKYLIGHT_HDR_PATH'] || ENV['SKYLIGHT_LIB_PATH'] || '.'
SKYLIGHT_LIB_PATH = ENV['SKYLIGHT_LIB_PATH'] || File.expand_path("../../lib/skylight/native/#{Platform.tuple}", __FILE__)

SKYLIGHT_SOURCE_URL = ENV['SKYLIGHT_SOURCE_URL']
SKYLIGHT_VERSION = ENV['SKYLIGHT_VERSION']
SKYLIGHT_CHECKSUM = ENV['SKYLIGHT_CHECKSUM']

SKYLIGHT_EXT_STRICT = ENV.key?("SKYLIGHT_EXT_STRICT") && ENV['SKYLIGHT_EXT_STRICT'] =~ /^true$/i

# Setup logger
LOG = Logger.new(MultiIO.new(STDOUT, File.open(SKYLIGHT_INSTALL_LOG, 'a')))

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

# Check that Xcode license has been approved
# Based on Homebrew's implementation
# https://github.com/Homebrew/homebrew/blob/03708b016755847facc4f19a43ee9f7a44141ed7/Library/Homebrew/cmd/doctor.rb#L1183
if Platform::OS == 'darwin'
  # If the user installs Xcode-only, they have to approve the
  # license or no "xc*" tool will work.
  if `/usr/bin/xcrun clang 2>&1` =~ /license/ && !$?.success?
    fail <<-EOS
You have not agreed to the Xcode license and so we are unable to build the native agent.
To resolve this, you can agree to the license by opening Xcode.app or running:
    sudo xcodebuild -license
EOS
  end
end

#
# === Setup paths
#
root              = File.expand_path('../', __FILE__)
hdrpath           = File.expand_path(SKYLIGHT_HDR_PATH)
libpath           = File.expand_path(SKYLIGHT_LIB_PATH)
libskylight       = File.expand_path("libskylight.#{Platform.libext}", libpath)
libskylight_yml   = File.expand_path('libskylight.yml', root)
skylight_dlopen_h = File.expand_path("skylight_dlopen.h", hdrpath)
skylight_dlopen_c = File.expand_path("skylight_dlopen.c", hdrpath)

LOG.info "SKYLIGHT_HDR_PATH=#{hdrpath}; SKYLIGHT_LIB_PATH=#{libpath}"

LOG.info "file exists; path=#{libskylight}" if File.exists?(libskylight)
LOG.info "file exists; path=#{skylight_dlopen_c}" if File.exists?(skylight_dlopen_c)
LOG.info "file exists; path=#{skylight_dlopen_h}" if File.exists?(skylight_dlopen_h)

# If libskylight is not present, fetch it
if !File.exist?(libskylight) && !File.exist?(skylight_dlopen_c) && !File.exist?(skylight_dlopen_h)
  if !SKYLIGHT_FETCH_LIB
    fail "libskylight.#{LIBEXT} not found -- remote download disabled; aborting install"
  end

  # Ensure that libskylight.yml is present and load it
  unless File.exist?(libskylight_yml)
    fail "`#{libskylight_yml}` does not exist"
  end

  unless libskylight_info = YAML.load_file(libskylight_yml)
    fail "`#{libskylight_yml}` does not contain data"
  end

  if version = SKYLIGHT_VERSION
    unless checksum = SKYLIGHT_CHECKSUM
      fail "no checksum provided when using custom version"
    end
  else
    unless version = libskylight_info["version"]
      fail "libskylight version missing from `#{libskylight_yml}`"
    end

    unless checksums = libskylight_info["checksums"]
      fail "libskylight checksums missing from `#{libskylight_yml}`"
    end

    unless checksum = checksums[Platform.tuple]
      fail "no checksum entry for requested architecture -- " \
               "this probably means the requested architecture is not supported; " \
               "platform=#{Platform.tuple}; available=#{checksums.keys}", :info
    end
  end

  begin
    res = NativeExtFetcher.fetch(
      source:   SKYLIGHT_SOURCE_URL,
      version:  version,
      target:   hdrpath,
      checksum: checksum,
      arch:     Platform.tuple,
      required: SKYLIGHT_REQUIRED,
      platform: Platform.tuple,
      logger:   LOG)

    unless res
      fail "could not fetch archive -- aborting skylight native extension build"
    end

    # Move skylightd & libskylight to appropriate directory
    if hdrpath != libpath
      # Ensure the directory is present
      FileUtils.mkdir_p libpath

      # Move
      FileUtils.mv "#{hdrpath}/libskylight.#{Platform.libext}",
                   "#{libpath}/libskylight.#{Platform.libext}",
                   :force => true

      FileUtils.mv "#{hdrpath}/skylightd",
                   "#{libpath}/skylightd",
                   :force => true
    end
  rescue => e
    fail "unable to fetch native extension; msg=#{e.message}\n#{e.backtrace.join("\n")}"
  end
end

#
#
# ===== By this point, libskylight is present =====
#
#

def find_file(file, root = nil)
  path = File.expand_path(file, root || '.')

  unless File.exist?(path)
    fail "#{file} missing; path=#{root}"
  end
end

$VPATH  << libpath

# Where the ruby binding src is
SRC_PATH = File.expand_path('..', __FILE__)

$srcs = Dir[File.expand_path("*.c", SRC_PATH)].map { |f| File.basename(f) }

# If the native agent support files were downloaded to a different directory,
# explicitly the file to the list of sources.
unless $srcs.include?('skylight_dlopen.c')
  $srcs << "skylight_dlopen.c" # From libskylight dist
end

# Make sure that the files are present
find_file 'skylight_dlopen.h', hdrpath
find_file 'skylight_dlopen.c', hdrpath
find_header 'skylight_dlopen.h', hdrpath
have_header 'dlfcn.h' or fail "could not create Makefile; dlfcn.h missing"

# For escaping the GVL
unless have_func('rb_thread_call_without_gvl', 'ruby/thread.h')
  have_func('rb_thread_blocking_region') or abort "Ruby is unexpectedly missing rb_thread_blocking_region. This should not happen."
end

# Previous comment stated:
#   -Werror is needed for the fast thread local storage
#
# Despite this comment, everything appears to build fine without the flag on. Since this
#   flag can cause issues for some customers we're turning it off by default. However,
#   in development and CI, we still have the option of turning it back on to help catch
#   potential issues.
if SKYLIGHT_EXT_STRICT
  $CFLAGS << " -Werror"
end

checking_for 'fast thread local storage' do
  if try_compile("__thread int foo;")
    $defs << "-DHAVE_FAST_TLS"
    true
  end
end

# Flag -std=c99 required for older build systems
$CFLAGS << " -std=c99 -Wall -fno-strict-aliasing"

# Allow stricter checks to be turned on for development or debugging
if SKYLIGHT_EXT_STRICT
  $CFLAGS << " -pedantic"
end

# TODO: Compute the relative path to the location
create_makefile 'skylight_native', File.expand_path('..', __FILE__) # or fail "could not create makefile"
