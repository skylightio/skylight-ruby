require 'yaml'

module Skylight
  class Config
    ENV_TO_KEY = {
      'SK_APPLICATION'    => :application,
      'SK_AUTHENTICATION' => :authentication }

    DEFAULTS = {
      :'report.host'    => 'agent.skylight.io'.freeze,
      :'report.port'    => 443,
      :'report.ssl'     => true,
      :'report.deflate' => true }.freeze

    def self.load(path = nil, environment = nil, env = ENV)
      attrs = {}

      if path
        attrs = YAML.load_file(path)
      end

      if env
        attrs[:priority] = remap_env(env)
      end

      new(environment, attrs)
    end

    def self.remap_env(env)
      ret = {}

      env.each do |k, val|
        if key = ENV_TO_KEY[k]
          ret[key] = val
        end
      end if env

      ret
    end

    def initialize(*args)
      attrs = {}

      if Hash === args.last
        attrs = args.pop
      end

      @values   = {}
      @priority = {}
      @regexp   = nil

      p = attrs.delete(:priority)

      if @environment = args[0]
        @regexp = /^#{Regexp.escape(@environment)}\.(.+)$/
      end

      attrs.each do |k, v|
        self[k] = v
      end

      if p
        p.each do |k, v|
          @priority[k.to_sym] = v
        end
      end
    end

    def get(key, default = nil, &blk)
      key = key.to_sym

      return @priority[key] if @priority.key?(key)
      return @values[key]   if @values.key?(key)
      return DEFAULTS[key]  if DEFAULTS.key?(key)

      if default
        return default
      elsif blk
        return blk.call(key)
      end

      nil
    end

    alias [] get

    def set(key, val, scope = nil)
      if scope
        key = [scope, key].join('.')
      end

      if Hash === val
        val.each do |k, v|
          set(k, v, key)
        end
      else
        if @regexp && key =~ @regexp
          @priority[$1.to_sym] = val
        end

        @values[key.to_sym] = val
      end
    end

    alias []= set

    #
    #
    # ===== Helpers =====
    #
    #

    def worker
      Worker::Builder.new(self)
    end

  end
end
