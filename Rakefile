$:.unshift File.expand_path('../lib', __FILE__)

require 'bundler/setup'
require 'fileutils'
require 'rbconfig'
require 'skylight/util/platform'

begin
  require 'yard'
rescue LoadError
end

include FileUtils
include Skylight::Util

def run_cmd(cmd)
  puts "$ #{cmd}"
  system("#{cmd} 2>&1")
end

ROOT = File.expand_path("..", __FILE__)

# Ruby extension output
TARGET_DIR = "#{ROOT}/target/#{Platform.tuple}"

# Normally this ends up in /lib, but for local dev it's easier to put it here
RUBY_EXT = "#{TARGET_DIR}/skylight_native.#{Platform.dlext}"

namespace :build do
  C_SRC = Dir["#{ROOT}/ext/{*.c,extconf.rb}"]

  # If the native lib location is specified locally, depend on it as well
  if native = ENV['SKYLIGHT_LIB_PATH']
    C_SRC.concat Dir[File.expand_path("../*.{c,h}", native)]
  end

  file RUBY_EXT => C_SRC do
    extconf = File.expand_path("../ext/extconf.rb", __FILE__)

    # Make sure that the directory is present
    mkdir_p TARGET_DIR
    mkdir_p File.dirname(RUBY_EXT)

    chdir TARGET_DIR do
      Bundler.with_clean_env do
        env = { SKYLIGHT_LIB_PATH: native,
                SKYLIGHT_REQUIRED: true}.map{|k,v| "#{k}=#{v}" if v }.compact.join(' ')

        run_cmd "#{env} ruby #{extconf}" or abort "failed to configure ruby ext"

        run_cmd "make" or abort "failed to build ruby ext"
      end
    end
  end
end

desc "build the ruby extension"
task :build => RUBY_EXT

desc "clean build artifacts"
task :clean do
  rm_rf "lib/skylight/native"
  rm_rf TARGET_DIR
end

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = '--order random'
end
task :spec => :build

namespace :vendor do
  namespace :update do
    task :highline do
      rm_rf "lib/skylight/vendor/cli/highline*"

      mkdir_p "tmp/vendor"
      cd "tmp/vendor" do
        rm_rf "highline*"
        sh "gem update highline"
        sh "gem unpack highline"
      end

      cp_r Dir["tmp/vendor/highline*/lib/*"], "lib/skylight/vendor/cli/"
    end
  end
end

if defined?(YARD)
  # See .yardopts
  YARD::Rake::YardocTask.new
end

task :default => :spec
