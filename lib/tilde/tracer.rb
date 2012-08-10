module Tilde
  class Tracer
    def self.new
      __allocate
    end

    def record(category, description = nil, annotations = nil)
      __record(category, description, annotations)
    end

    def start(category, description = nil, annotations = nil)
      # stuff
    end

    alias stop __stop

  private

    def record?(category, description)
      String === category
    end

  end
end
