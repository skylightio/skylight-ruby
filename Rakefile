$:.unshift File.expand_path('../lib', __FILE__)

require 'bundler/setup'
require 'fileutils'
require 'rbconfig'
require 'yard'
require 'skylight/util/platform'

include FileUtils
include Skylight::Util

ROOT = File.expand_path("..", __FILE__)

# Ruby extension output
TARGET_DIR = ENV['SKYLIGHT_RUBY_EXT_PATH'] || "#{ROOT}/target/#{Platform.tuple}"

# Path to the ruby extension
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

    chdir TARGET_DIR do
      Bundler.with_clean_env do
        sh "SKYLIGHT_REQUIRED=true ruby #{extconf}" or abort "failed to configure ruby ext"
        sh "make" or abort "failed to build ruby ext"
      end
    end
  end
end

desc "build the ruby extension"
task :build => RUBY_EXT

task :spec => :build do
  ruby_ext_dir = File.dirname(RUBY_EXT)
  ENV['SKYLIGHT_LIB_PATH'] = ruby_ext_dir
  ENV["RUBYOPT"] = "#{ENV["RUBYOPT"]} -I#{ruby_ext_dir}"

  # Shelling out to rspec vs. invoking the runner in process fixes exit
  # statuses.
  Dir.chdir File.expand_path('../', __FILE__) do
    sh [ "ruby -rbundler/setup -S rspec", ENV['args'] ].join(' ')
  end
end

desc "clean build artifacts"
task :clean do
  rm_rf Dir["#{TARGET_DIR}/{*.a,*.o,*.so,*.bundle}"]
  rm_rf Dir["lib/skylight_native.{a,o,so,bundle}"]
  rm_rf "target"
end

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

# See .yardopts
YARD::Rake::YardocTask.new

task :default => :spec
