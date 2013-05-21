require 'zlib'

module Skylight
  module Util
    module Gzip
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
