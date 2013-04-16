module Skylight
  module Normalize
    @registry = {}

    def self.normalize(trace, name, payload, config={})
      klass = @registry[name]

      if klass
        klass.new(trace, name, payload, config).normalize
      else
        Default.new(trace, name, payload, config).normalize
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

    def initialize(trace, name, payload, config={})
      @trace, @name, @payload, @config = trace, name, payload, config
    end
  end

  class RenderNormalizer < Normalizer
  private
    def normalize_render(category, payload)
      path = @payload[:identifier]

      title = relative_path(path)
      path = nil if path == title
      [ category, title, path, payload ]
    end

    def relative_path(path)
      root_path = @config.view_paths.find do |p|
        path.start_with?(p)
      end

      if root_path
        relative = path[root_path.size..-1]
        relative = relative[1..-1] if relative.start_with?("/")
        relative
      else
        path
      end
    end
  end
end

require "skylight/normalize/default"
require "skylight/normalize/start_processing"
require "skylight/normalize/process_action"
require "skylight/normalize/render_collection"
require "skylight/normalize/render_template"
require "skylight/normalize/render_partial"
require "skylight/normalize/send_file"
require "skylight/normalize/sql"
