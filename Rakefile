require 'bundler/setup'
require 'rbconfig'
require 'yard'

task :spec do
  platform = Gem::Platform.local
  ext = RbConfig::CONFIG['DLEXT']

  # The possible locations for the native extension
  native_ext = [
    # Allows the location of the native extension to be specified externally
    ENV['RUBY_SKYLIGHT_NATIVE_PATH'],
    # The platform scoped location
    File.expand_path("../target/#{platform.os}/#{platform.cpu}/skylight_native.#{ext}"),
    # The default extconf output directory
    File.expand_path("../ext/skylight_native.#{ext}")
  ].detect { |f| f && File.exist?(f) }

  if native_ext
    native_ext_dir = File.dirname(native_ext)
    ENV["RUBYOPT"] = "#{ENV["RUBYOPT"]} -I#{native_ext_dir}"
  end

  # Shelling out to rspec vs. invoking the runner in process fixes exit
  # statuses.
  Dir.chdir File.expand_path('../', __FILE__) do
    sh [ "ruby -rbundler/setup -S rspec", ENV['args'] ].join(' ')
  end
end

desc "clean build artifacts"
task :clean do
  rm_rf Dir["ext/{*.a,*.o,*.so,*.bundle}"]
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
