module Tilde
  class Subscriber

    def start(name, id, payload)
      p [ :GOT, name ]
    end

    def finish(name, id, payload)
      p [ :GOT, name ]
    end

  end
end
