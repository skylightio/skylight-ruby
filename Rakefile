require 'rbconfig'

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
  ].detect { |f| File.exist?(f) }

  if native_ext
    native_ext_dir = File.dirname(native_ext)
    ENV["RUBYOPT"] = "#{ENV["RUBYOPT"]} -I#{native_ext_dir}"
  end

  # Shelling out to rspec vs. invoking the runner in process fixes exit
  # statuses.
  Dir.chdir File.expand_path('../', __FILE__) do
    sh "ruby -rbundler/setup -S rspec spec"
  end
end

desc "clean build artifacts"
task :clean do
  rm_rf Dir["ext/{*.a,*.o,*.so,*.bundle}"]
  rm_rf "target"
end

task :default => :spec
