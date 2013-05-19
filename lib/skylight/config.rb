require 'yaml'

module Skylight
  class Config
    ENV_TO_KEY = {
      'SK_APPLICATION' => :application,
      'SK_TOKEN'       => :token }

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

      if p = attrs.delete(:priority)
        p.each do |k, v|
          @priority[k.to_sym] = v
        end
      end

      if @environment = args[0]
        @regexp = /^#{Regexp.escape(@environment)}\.(.+)$/
      end

      attrs.each do |k, v|
        self[k] = v
      end
    end

    def get(key, default = nil, &blk)
      key = key.to_sym

      return @priority[key] if @priority.key?(key)
      return @values[key]   if @values.key?(key)

      if default && blk
        raise ArgumentError, "cannot pass in both a default value and block"
      end

      default || blk.call(key)
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
          @priority[$1.to_sym] ||= val
        end

        @values[key.to_sym] = val
      end
    end

    alias []= set

  end
end
