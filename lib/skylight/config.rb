module Skylight
  class Config

    def self.load_from_yaml(path)
      new
    end

    def authentication_token
      "8yagFhG61tYeY4j18K8+VpI0CyG4sht5J2Oj7RQL05RhcHBsaWNhdGlvbl9pZHM9Zm9vJnJvbGU9YWdlbnQ="
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
