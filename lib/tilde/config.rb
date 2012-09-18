module Tilde
  class Config

    def self.load_from_yaml(path)
      new
    end

    def authentication_token
      "AcfPGMFrxrw2TER08b0HYgn1LGpcAAAAAAfrGCxlLGmz20oUr+F6CSgA+OvQvCdNdA=="
    end

    def ssl?
      false
    end

    def deflate?
      # true
    end

    def host
      "localhost"
    end

    def port
      8080
    end

    def samples_per_interval
      100
    end

    def interval
      5
    end

    def max_pending_traces
      1_000
    end

  end
end
