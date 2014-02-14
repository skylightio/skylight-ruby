module Skylight
  module Messages
    require 'skylight/messages/trace'
    require 'skylight/messages/hello'
    require 'skylight/messages/error'
    require 'skylight/messages/trace_envelope'

    KLASS_TO_ID = {
      Skylight::Trace => 0,
      Skylight::Hello => 1,
      Skylight::Error => 2
    }

    ID_TO_KLASS = {
      0 => Skylight::Messages::TraceEnvelope,
      1 => Skylight::Hello,
      2 => Skylight::Error
    }
  end
end
