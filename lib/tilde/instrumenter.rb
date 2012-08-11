module Tilde
  class Instrumenter

    def self.new
      __allocate
    end

    alias start    __start
    alias shutdown __shutdown

  end
end
