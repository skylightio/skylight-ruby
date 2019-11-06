require "pathname"

module SpecHelper
  module Path
    module_function

      def root
        @root ||= Pathname.new(ENV.fetch("SKYLIGHT_TEST_DIR", File.expand_path("../..", __dir__)))
      end

      def tmp(*path)
        root.join("tmp/spec", *path)
      end

      def lockfile
        tmp("skylight.pid")
      end

      def sockdir_path(*args)
        tmp(*args)
      end
  end

  include Path
end

class Pathname
  def mkdir_p
    FileUtils.mkdir_p(self)
  end

  def touch
    dirname.mkdir_p
    FileUtils.touch(self)
  end

  def rm
    unlink
  end

  def write(content)
    dirname.mkdir_p
    File.open(self, "w") { |f| f.write(content) }
  end
end
