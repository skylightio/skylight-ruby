# frozen_string_literal: true

module Skylight::Core::Normalizers::GraphQL
  # Some AS::N events in GraphQL are not super useful.
  # We are purposefully ignoring the following keys (and you probably shouldn't add them):
  #  - "graphql.analyze_multiplex"
  #  - "graphql.execute_field" (very frequently called)
  #  - "graphql.execute_field_lazy"

  class Base < Skylight::Core::Normalizers::Normalizer
    ANONYMOUS = "[anonymous]".freeze
    CAT = "app.graphql".freeze

    def normalize(_trace, name, _payload)
      [CAT, name, nil]
    end
  end

  class Lex < Base
    register "graphql.lex"
  end

  class Parse < Base
    register "graphql.parse"
  end

  class Validate < Base
    register "graphql.validate"
  end

  class ExecuteMultiplex < Base
    register "graphql.execute_multiplex"
    def normalize_after(trace, _span, _name, payload)
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
      queries, has_errors = payload[:multiplex].queries.each_with_object([Set.new, Set.new]) do |query, (names, errors)|
        names << (query.operation_name || ANONYMOUS)
        errors << query.static_errors.any?
      end

      trace.endpoint = "graphql:#{queries.sort.join('+')}"
      trace.compound_response_error_status = if has_errors.all?
                                               :all
                                             elsif !has_errors.none?
                                               :partial
                                             end
    end
  end

  class AnalyzeQuery < Base
    register "graphql.analyze_query"
  end

  class ExecuteQuery < Base
    register "graphql.execute_query"

    def normalize(trace, name, payload)
      query_name = payload[:query]&.operation_name || ANONYMOUS

      if query_name == ANONYMOUS
        meta = { mute_children: true }
      end

      # This is probably always overriden by execute_multiplex#normalize_after,
      # but in the case of a single query, it will be the same value anyway.
      trace.endpoint = "graphql:#{query_name}"

      [CAT, "#{name}: #{query_name}", nil, meta]
    end
  end

  class ExecuteQueryLazy < ExecuteQuery
    register "graphql.execute_query_lazy"

    def normalize(trace, name, payload)
      if payload[:query]
        super
      elsif payload[:multiplex]
        [CAT, "#{name}.multiplex", nil]
      end
    end
  end
end
