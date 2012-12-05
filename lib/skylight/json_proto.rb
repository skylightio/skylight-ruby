require 'json'

module Skylight
  class JsonProto
    def write(out, counts, sample)
      puts "WRITE: #{out}, #{counts}, #{sample}"
    end
  end
end
