require "bundler/setup"
require "fileutils"
require "rbconfig"
require "rake/extensiontask"
require "English"
require "syntax_tree/rake_tasks"

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
    ENV["SKYLIGHT_EXT_STRICT"] = ENV.fetch("SKYLIGHT_EXT_STRICT", nil) =~ /^false$/i ? nil : "true"
    super
  ensure
    ENV.replace(original_env)
  end
end

ExtensionTask.new do |ext|
  ext.name = "skylight_native"
  ext.ext_dir = "ext"
  ext.source_pattern = "*.{c,h}"
  ext.native_lib_path = ENV.fetch("SKYLIGHT_LIB_PATH", nil)
end

CLEAN << File.expand_path("ext/install.log", __dir__)
CLOBBER << File.expand_path("lib/skylight/native", __dir__)

# rubocop:disable Lint/SuppressedException
begin
  require "yard"
rescue LoadError
end
# rubocop:enable Lint/SuppressedException

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec) { |t| t.rspec_opts = "--order random" }
task spec: :compile

require "rubocop/rake_task"
RuboCop::RakeTask.new(:rubocop)

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

Rake.add_rakelib "lib/tasks"

[SyntaxTree::Rake::WriteTask, SyntaxTree::Rake::CheckTask].each do |stree|
  stree.new do |t|
    t.source_files = FileList[%w[**/*.rb tasks/**/*.rake .pryrc config.ru Rakefile Gemfile]]
    t.ignore_files = "lib/skylight/vendor/**/*"
    t.print_width = 120
  end
end

task default: %i[spec]
