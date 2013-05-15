require 'pathname'

module SpecHelper
  module Path
    def root
      @root ||= Pathname.new(File.expand_path("../../..", __FILE__))
    end

    def tmp(*path)
      root.join("tmp", *path)
    end

    def lockfile
      tmp("skylight.pid")
    end

    extend self
  end
end
