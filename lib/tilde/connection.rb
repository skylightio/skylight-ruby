module Tilde
  class Connection

    def self.open(host, port, ssl)
      conn = new(host, port, ssl)
      conn.open
      conn
    end

    def initialize(host, port, ssl)
      @host = host
      @port = port
      @ssl  = ssl
    end

    def open
      # stuff
    end

    def close
      # stuff
    end

  end
end
