module Skylight
  module Messages
    require 'skylight/messages/annotation'
    require 'skylight/messages/event'
    require 'skylight/messages/span'
    require 'skylight/messages/trace'
    require 'skylight/messages/endpoint'
    require 'skylight/messages/batch'
    require 'skylight/messages/hello'
    require 'skylight/messages/error'
    require 'skylight/messages/trace_envelope'

    KLASS_TO_ID = {
      Skylight::Hello => 1,
      Skylight::Trace => 2,
      Skylight::Messages::Error => 3
    }

    ID_TO_KLASS = {
      1 => Skylight::Hello,
      2 => Skylight::Messages::TraceEnvelope,
      3 => Skylight::Messages::Error
    }
  end
end
