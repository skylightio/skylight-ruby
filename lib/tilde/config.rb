module Tilde
  class Config

    def self.load_from_yaml(path)
      new
    end

    def ssl?
      false
    end

    def host
      "localhost"
    end

    def port
      3000
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
