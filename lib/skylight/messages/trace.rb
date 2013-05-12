module Skylight
  module Messages
    class Trace < Base

      required :uuid, :string, 1
      required :pid,  Pid,     2

    end
  end
end
