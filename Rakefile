require "bundler/setup"
require "fileutils"
require "rbconfig"
require "rake/extensiontask"
require "English"

class ExtensionTask < Rake::ExtensionTask
  attr_accessor :native_lib_path

  def source_files
    files = super
    files += FileList["#{native_lib_path}/*.{c,h}"] if native_lib_path
    files
  end

  def sh(*cmd)
    original_env = ENV.to_hash
    ENV["SKYLIGHT_REQUIRED"] = "true"
    ENV["SKYLIGHT_EXT_STRICT"] = ENV["SKYLIGHT_EXT_STRICT"] !~ /^false$/i ? "true" : nil
    super
  ensure
    ENV.replace(original_env)
  end
end

ExtensionTask.new do |ext|
  ext.name = "skylight_native"
  ext.ext_dir = "ext"
  ext.source_pattern = "*.{c,h}"
  ext.native_lib_path = ENV["SKYLIGHT_LIB_PATH"]
end

CLEAN << File.expand_path("ext/install.log", __dir__)
CLOBBER << File.expand_path("lib/skylight/native", __dir__)

# rubocop:disable Lint/HandleExceptions
begin
  require "yard"
rescue LoadError
end
# rubocop:enable Lint/HandleExceptions

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = "--order random"
end
task spec: :compile

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

def travis_config
  require "yaml"
  @travis_config ||= YAML.load_file(".travis.yml")
end

def travis_builds
  return @travis_builds if @travis_builds

  config = travis_config
  stages = config["stages"]
  builds = []

  config["env"]["matrix"].each do |env|
    config["rvm"].each do |rvm|
      config["gemfile"].each do |gemfile|
        builds << {
          "stage"   => "test",
          "env"     => Array(env).compact,
          "rvm"     => rvm,
          "gemfile" => gemfile
        }
      end
    end
  end

  config["jobs"]["exclude"].each do |build|
    builds.reject! do |b|
      build.to_a.all? do |(k, v)|
        v = Array(v) if k == "env"
        b[k] == v
      end
    end
  end

  builds += config["jobs"]["include"]

  builds.each do |b|
    config["jobs"]["allow_failures"].each do |build|
      b["allow_failure"] ||= build.to_a.all? do |(k, v)|
        v = Array(v) if k == "env"
        b[k] == v
      end
    end
  end

  # Group by stage
  stage_groups = builds.group_by { |build| build["stage"] }
  builds = stages.map do |stage|
    stage_builds = stage_groups[stage]
    # Move allowed_failures to the end
    allowed_failures = stage_builds.select { |b| b["allow_failure"] }
    stage_builds = (stage_builds - allowed_failures) + allowed_failures
    stage_builds
  end.flatten

  builds.each.with_index do |build, index|
    build["number"] = index + 1
  end

  @travis_builds = builds
end

task :vagrant_up do
  unless ENV["SKIP_PROVISION"]
    system("vagrant up --provision")
  end
end

task run_travis_builds: :vagrant_up do
  builds = travis_builds

  if (number = ENV["JOB"])
    if (target_build = builds.find { |b| b["number"] == number.to_i })
      builds = [target_build]
    else
      abort "No build for number: #{number}"
    end
  end

  # Set variables here before we do with_clean_env
  no_clean = ENV["NO_CLEAN"]
  rspec_args = ENV["RSPEC"]
  debug = ENV["DEBUG"]

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
      ]

      commands += travis_config["env"]["global"].map { |env| "export #{env}" }

      commands += Array(build["env"]).map { |env| "export #{env}" }

      commands << "export DEBUG=1" if debug

      commands << "bundle update"

      commands << "pushd skylight-core"
      commands <<
        if rspec_args
          "bundle exec rspec #{rspec_args}"
        else
          "bundle exec rake"
        end
      commands << "popd"

      commands << "bundle exec rake clobber" unless no_clean

      if rspec_args
        commands << "bundle exec rake compile"
        commands << "bundle exec rspec #{rspec_args}"
      else
        commands << "bundle exec rake"
      end

      command = commands.join(" && ")

      # TODO: May need special handling for quotation marks
      system("vagrant ssh -c \"#{command}\"")
      build["success"] = $CHILD_STATUS.success?
    end
  end

  successful = builds.select { |b| b["success"] }
  failed = builds.reject { |b| b["success"] }

  puts "Completed: #{builds.count}, Successful: #{successful.count}, Failed: #{failed.count}"

  if failed.count > 0
    puts "Failures:"
    failed.each do |build|
      puts "  #{build['number']}: #{build.inspect}"
    end
  end

  raise if failed.count > 0
end

task :list_travis_builds do
  travis_builds.each do |build|
    puts "#{build['number']}: #{build.inspect}"
  end
end

task default: :spec
