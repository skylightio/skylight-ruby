module SpecHelper
  SPECIAL_HEADERS = %w[CONTENT_TYPE REQUEST_METHOD rack.input].freeze

  RSpec::Matchers.define :be_request do |*args|
    hdrs = {}
    hdrs = args.pop if args[-1].is_a?(Hash)
    path = args.shift

    match do |env|
      @fails = []
      @env = env
      if env
        ret = true

        ret &= match_header(env, "PATH_INFO", path) if path

        hdrs.each do |k, v|
          k = "rack.input" if k == :input

          unless SPECIAL_HEADERS.include?(k)
            k = k.to_s.upcase.tr("-", "_")
            k = "HTTP_#{k}" unless SPECIAL_HEADERS.include?(k)
          end

          ret &= match_header(env, k, v)
        end

        ret
      end
    end

    def match_header(env, key, val)
      ret =
        case val
        when Regexp
          env[key] =~ val
        else
          env[key] == val
        end

      @fails << { key: key, actual: env[key], expected: val } unless ret

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

  RSpec::Matchers.define :a_span_including do |expected|
    match { |actual| expect(actual.to_hash).to match(a_hash_including(expected)) }

    failure_message { "span match failed" }

    failure_message_when_negated { "span match negated failed" }
  end

  RSpec::Matchers.define :an_exact_span do |expected|
    match { |actual| expect(actual.to_hash).to eq(expected) }

    failure_message { "an exact span match failed" }

    failure_message_when_negated { "an exact span match negated failed" }
  end

  RSpec::Matchers.define :an_event_including do |expected|
    match { |actual| expect(actual.to_hash).to match(a_hash_including(expected)) }

    failure_message { "event match failed" }

    failure_message_when_negated { "event match negated failed" }
  end

  RSpec::Matchers.define :an_exact_event do |expected|
    match { |actual| expect(actual.to_hash).to eq(expected) }

    failure_message { "an exact event match failed" }

    failure_message_when_negated { "an exact event match negated failed" }
  end

  RSpec::Matchers.define :an_annotation do |expected_type, expected_value|
    match do |actual|
      actual_hash = actual.to_hash

      expected_key = SpecHelper::Messages::Annotation::AnnotationKey.const_get(expected_type)
      expect(actual_hash[:key]).to eq(expected_key)

      actual_value =
        case expected_value
        when Integer
          actual_hash[:val][:uint_val]
        when String
          actual_hash[:val][:string_val]
        else
          raise TypeError, "unknown value type; #{expected_value.class}"
        end

      expect(actual_value).to eq(expected_value)
    end

    failure_message { "an annotation match failed" }

    failure_message_when_negated { "an annotation match negated failed" }
  end

  def get_json(*args)
    hdrs = {}
    hdrs = args.pop if args[-1].is_a?(Hash)
    hdrs["accept"] = "application/json"
    hdrs["request-method"] = "GET"

    be_request(*args, hdrs)
  end

  def post_json(*args)
    hdrs = {}
    hdrs = args.pop if args[-1].is_a?(Hash)
    hdrs["accept"] = "application/json"
    hdrs["content-type"] = "application/json"
    hdrs["request-method"] = "POST"

    be_request(*args, hdrs)
  end
end
