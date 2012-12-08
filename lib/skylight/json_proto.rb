require 'json'

module Skylight
  class JsonProto
    def write(out, counts, sample)
      json = {
        counts: counts,
        sample: sample
      }.to_json
      out << json
    end
  end
end
