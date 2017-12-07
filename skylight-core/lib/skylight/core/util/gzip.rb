require 'zlib'

module Skylight::Core
  module Util
    # Provides Gzip compressing support
    module Gzip

      # Compress a string with Gzip
      #
      # @param str [String] uncompressed string
      # @return [String] compressed string
      def self.compress(str)
        output = StringIO.new
        gz = Zlib::GzipWriter.new(output)
        gz.write(str)
        gz.close
        output.string
      end
    end
  end
end
