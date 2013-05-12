module Skylight
  module Messages
    class Pid < Base

      required :pid,     :uint32, 1
      optional :version, :string, 2

    end
  end
end
