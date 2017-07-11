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

def run_cmd(cmd, env={})
  puts "system(#{env.inspect} #{cmd})"
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

    # Default to true for local use
    strict = ENV['SKYLIGHT_EXT_STRICT'] !~ /^false$/i

    chdir TARGET_DIR do
      Bundler.with_clean_env do
        env = { SKYLIGHT_LIB_PATH: native,
                SKYLIGHT_REQUIRED: true,
                SKYLIGHT_EXT_STRICT: strict }

        run_cmd("ruby #{extconf}", env) or abort "failed to configure ruby ext"

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
  rm_f "ext/install.log"
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

def get_travis_builds
  require 'yaml'
  config = YAML.load_file(".travis.yml")

  builds = []

  config["env"]["matrix"].each do |env|
    config["rvm"].each do |rvm|
      config["gemfile"].each do |gemfile|
        builds << {
          "env"     => Array(env).compact,
          "rvm"     => rvm,
          "gemfile" => gemfile
        }
      end
    end
  end

  config["matrix"]["exclude"].each do |build|
    builds.reject! do |b|
      build.to_a.all? do |(k,v)|
        v = Array(v) if k == 'env'
        b[k] == v
      end
    end
  end

  builds += config["matrix"]["include"]


  builds.each do |b|
    config["matrix"]["allow_failures"].each do |build|
      b['allow_failure'] ||= build.to_a.all? do |(k,v)|
        v = Array(v) if k == 'env'
        b[k] == v
      end
    end
  end

  # Move allowed_failures to the end
  allowed_failures = builds.select{|b| b['allow_failure']}
  builds = (builds - allowed_failures) + allowed_failures

  builds.each.with_index do |build, index|
    build["number"] = index + 1
  end

  builds
end

task :vagrant_up do
  unless ENV['SKIP_PROVISION']
    system("vagrant up --provision")
  end
end

task :run_travis_builds => :vagrant_up do |t|
  builds = get_travis_builds

  if number = ENV['JOB']
    if build = builds.find{|b| b['number'] == number.to_i }
      builds = [build]
    else
      abort "No build for number: #{number}"
    end
  end

  # Set variables here before we do with_clean_env
  no_clean = ENV['NO_CLEAN']
  rspec_args = ENV['RSPEC']
  debug = ENV['DEBUG']

  # Avoids issue with vagrant existing as a gem
  Bundler.with_clean_env do
    builds.each do |build|
      puts "#{build['number']}: #{build.inspect}"

      commands = [
        "cd /vagrant",
        "rvm use #{build['rvm']}",
        "gem install bundler",
        "export SKYLIGHT_SOCKDIR_PATH=/tmp", # Avoid NFS issues
        "export BUNDLE_GEMFILE=\\$PWD/#{build['gemfile']}", # Escape PWD so it runs on Vagrant, not local box
        "export SKYLIGHT_TEST_DIR=/tmp"
      ]

      commands += Array(build['env']).map{|env| "export #{env}" }

      commands << "export DEBUG=1" if debug

      commands << "bundle update"
      commands << "bundle exec rake clean" unless no_clean

      if rspec_args
        commands << "bundle exec rake build"
        commands << "bundle exec rspec #{rspec_args}"
      else
        commands << "bundle exec rake"
      end

      command = commands.join(" && ")

      # TODO: May need special handling for quotation marks
      system("vagrant ssh -c \"#{command}\"")
      build["success"] = $?.success?
    end
  end

  successful = builds.select{|b| b["success"] }
  failed = builds.reject{|b| b["success"] }

  puts "Completed: #{builds.count}, Successful: #{successful.count}, Failed: #{failed.count}"

  if failed.count > 0
    puts "Failures:"
    failed.each do |build|
      puts "  #{build['number']}: #{build.inspect}"
    end
  end

  fail if failed.count > 0
end

task :list_travis_builds do
  builds = get_travis_builds

  builds.each do |build|
    puts "#{build['number']}: #{build.inspect}"
  end
end

task :default => :spec
