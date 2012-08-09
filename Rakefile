require 'rake/extensiontask'

Rake::ExtensionTask.new "direwolf_native" do |ext|
  ext.lib_dir = 'lib/tilde'
  ext.source_pattern = "*.{c,cc}"
end

task :clean do
  rm_f Dir["lib/tilde/direwolf_native.*"]
end
