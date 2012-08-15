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

  end
end
