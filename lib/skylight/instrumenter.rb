module Skylight
  class Instrumenter < Core::Instrumenter
    def self.trace_class
      Trace
    end
  end
end
