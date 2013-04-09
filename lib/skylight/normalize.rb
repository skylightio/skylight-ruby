module Skylight
  module Normalize
    @registry = {}

    def self.normalize(trace, name, payload)
      klass = @registry[name]

      if klass
        klass.new(trace, name, payload).normalize
      else
        :skip
      end
    end

    def self.register(name, klass)
      @registry[name] = klass
    end
  end

  class Normalizer
    def self.register(name)
      Normalize.register(name, self)
    end

    def initialize(trace, name, payload)
      @trace, @name, @payload = trace, name, payload
    end
  end
end

require "skylight/normalize/start_processing"
require "skylight/normalize/process_action"
require "skylight/normalize/render_collection"
require "skylight/normalize/render_template"
require "skylight/normalize/render_partial"
require "skylight/normalize/send_file"
require "skylight/normalize/sql"
