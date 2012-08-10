module Tilde
  class Tracer
    def self.new
      __allocate
    end

    # Alias public methods to the native implementations
    #
    alias record __record
    alias start  __start
    alias stop   __stop

  end
end
