# frozen_string_literal: true

require "active_support/inflector"

module Skylight::Normalizers::GraphQL
  # Some AS::N events in GraphQL are not super useful.
  # We are purposefully ignoring the following keys (and you probably shouldn't add them):
  #  - "graphql.analyze_multiplex"
  #  - "graphql.execute_field" (very frequently called)
  #  - "graphql.execute_field_lazy"

  class Base < Skylight::Normalizers::Normalizer
    ANONYMOUS = "[anonymous]"
    CAT = "app.graphql"

    if defined?(::GraphQL::VERSION) && Gem::Version.new(::GraphQL::VERSION) >= Gem::Version.new("1.10")
      def self.register_graphql
        register("#{key}.graphql")
      end
    else
      def self.register_graphql
        register("graphql.#{key}")
      end
    end

    def self.inherited(klass)
      super
      klass.const_set(:KEY, ActiveSupport::Inflector.underscore(ActiveSupport::Inflector.demodulize(klass.name)).freeze)
    end

    def self.key
      self::KEY
    end

    def normalize(_trace, _name, _payload)
      [CAT, "graphql.#{key}", nil]
    end

    private

    def key
      self.class.key
    end

    def extract_query_name(query)
      query&.context&.[](:skylight_endpoint) || query&.operation_name || ANONYMOUS
    end
  end

  class Lex < Base
    register_graphql
  end

  class Parse < Base
    register_graphql
  end

  class Validate < Base
    register_graphql
  end

  class Execute < Base
    register_graphql

    # This is a new, combined normalizer for execute_query and execute_multiplex,
    # to be used for graphql >= 2.5
    #
    def normalize(trace, name, payload)
      if payload[:query]
        _execute_query_normalize(trace, name, payload)
      else
        [CAT, "graphql.#{key}", nil]
      end
    end

    def normalize_after(trace, span, name, payload)
      if payload[:multiplex]
        _execute_multiplex_normalize_after(trace, span, name, payload)
      end
    end

    private

    def _execute_query_normalize(trace, _name, payload)
      query_name = extract_query_name(payload[:query])

      meta = { mute_children: true } if query_name == ANONYMOUS
      # This is probably always overriden by execute_multiplex#normalize_after,
      # but in the case of a single query, it will be the same value anyway.
      trace.endpoint = "graphql:#{query_name}"

      [CAT, "graphql.#{key}: #{query_name}", nil, meta]
    end

    def _execute_multiplex_normalize_after(trace, _span, _name, payload)
      # This is in normalize_after because the queries may not have
      # an assigned operation name before they are executed.
      # For example, if you send a single query with a defined operation name, e.g.:
      # ```graphql
      #   query MyNamedQuery { user(id: 1) { name } }
      # ```
      # ... but do _not_ send the operationName request param, the GraphQL docs[1]
      # specify that the executor should use the operation name from the definition.
      #
      # In graphql-ruby's case, the calculation of the operation name is lazy, and
      # has not been done yet at the point where execute_multiplex starts.
      # [1] https://graphql.org/learn/serving-over-http/#post-request
      queries, has_errors =
        payload[:multiplex]
          .queries
          .each_with_object([Set.new, Set.new]) do |query, (names, errors)|
            names << extract_query_name(query)
            errors << query.static_errors.any?
          end

      trace.endpoint = "graphql:#{queries.sort.join("+")}"
      trace.compound_response_error_status =
        if has_errors.all?
          :all
        elsif has_errors.any?
          :partial
        end
    end
  end

  class ExecuteQuery < Execute
    register_graphql
  end

  class ExecuteMultiplex < Execute
    register_graphql

    # see behavior in Execute#_multiplex_normalize_after
  end

  class AnalyzeQuery < Base
    register_graphql
  end

  class ExecuteQueryLazy < ExecuteQuery
    register_graphql

    def normalize(trace, _name, payload)
      if payload[:query]
        super
      elsif payload[:multiplex]
        [CAT, "graphql.#{key}.multiplex", nil]
      end
    end
  end
end
