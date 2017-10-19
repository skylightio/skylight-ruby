module SpecHelper

  RSpec::Matchers.define :happen do |timeout = 1, interval = 0.1|

    match do |blk|
      res = false
      start = Time.now

      while timeout > Time.now - start
        if blk.call
          res = true
          break
        end

        sleep interval
      end

      res
    end

    failure_message do
      "expected block to happen but it didn't"
    end

    failure_message_when_negated do
      "expected block not to happen but it did"
    end

  end

  SPECIAL_HEADERS = %w(CONTENT_TYPE REQUEST_METHOD rack.input)

  RSpec::Matchers.define :be_request do |*args|

    hdrs  = {}
    hdrs  = args.pop if Hash === args[-1]
    path  = args.shift

    @fails = []

    match do |env|
      @env = env
      if env
        ret = true

        ret &= match_header(env, 'PATH_INFO', path) if path

        hdrs.each do |k, v|
          k = 'rack.input' if k == :input

          unless SPECIAL_HEADERS.include?(k)
            k = k.to_s.upcase.gsub('-', '_')
            k = "HTTP_#{k}" unless SPECIAL_HEADERS.include?(k)
          end

          ret &= match_header(env, k, v)
        end

        ret
      end
    end

    def match_header(env, key, val)
      ret = case val
      when Regexp then env[key] =~ val
      else env[key] == val
      end

      unless ret
        @fails << {
          key:      key,
          actual:   env[key],
          expected: val }
      end

      ret
    end

    failure_message do
      if @env
        lines = []
        @fails.each do |f|
          lines << "expected env[#{f[:key]}] " \
            "=~ #{f[:expected].inspect}, " \
            "but was #{f[:actual].inspect}"
        end

        lines.join("\n")
      else
        "request is nil"
      end
    end

  end

  def get_json(*args)
    hdrs = {}
    hdrs = args.pop if Hash === args[-1]
    hdrs['accept'] = 'application/json'
    hdrs['request-method'] = 'GET'

    be_request(*args, hdrs)
  end

  def post_json(*args)
    hdrs = {}
    hdrs = args.pop if Hash === args[-1]
    hdrs['accept'] = 'application/json'
    hdrs['content-type'] = 'application/json'
    hdrs['request-method'] = 'POST'

    be_request(*args, hdrs)
  end
end
