module Skylight
  module Normalizers
    module Moped
      class Query < Normalizer
        register "query.moped"

        CAT = "db.mongo.query".freeze

        def normalize(trace, name, payload)
          # payload: { prefix: "  MOPED: #{address.resolved}", ops: operations }

          # We can sometimes have multiple operations. However, it seems like this only happens when doing things
          # like an insert, followed by a get last error, so we can probably ignore all but the first.
          operation = payload[:ops] ? payload[:ops].first : nil
          type = operation && operation.class.to_s =~ /^Moped::Protocol::(.+)$/ ? $1 : nil

          case type
          when "Query".freeze   then normalize_query(operation)
          when "GetMore".freeze then normalize_get_more(operation)
          when "Insert".freeze  then normalize_insert(operation)
          when "Update".freeze  then normalize_update(operation)
          when "Delete".freeze  then normalize_delete(operation)
          else :skip
          end
        end

      private

        def normalize_query(operation)
          title = normalize_title("QUERY".freeze, operation)

          hash = extract_binds(operation.selector)
          description = hash.to_json

          [CAT, title, description]
        end

        def normalize_get_more(operation)
          title = normalize_title("GET_MORE".freeze, operation)

          [CAT, title, nil]
        end

        def normalize_insert(operation)
          title = normalize_title("INSERT".freeze, operation)

          [CAT, title, nil]
        end

        def normalize_update(operation)
          title = normalize_title("UPDATE".freeze, operation)

          selector_hash = extract_binds(operation.selector)
          update_hash = extract_binds(operation.update)

          description = { selector: selector_hash, update: update_hash }.to_json

          [CAT, title, description]
        end

        def normalize_delete(operation)
          title = normalize_title("DELETE".freeze, operation)

          hash = extract_binds(operation.selector)
          description = hash.to_json

          [CAT, title, description]
        end

        def normalize_title(type, operation)
          "#{type} #{operation.collection}"
        end

        def extract_binds(hash)
          ret = {}

          hash.each do |k,v|
            if v.is_a?(Hash)
              ret[k] = extract_binds(v)
            else
              ret[k] = '?'.freeze
            end
          end

          ret
        end

      end
    end
  end
end
