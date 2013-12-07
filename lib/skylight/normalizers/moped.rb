module Skylight
  module Normalizers
    class Moped < Normalizer
      register "query.moped"

      CAT = "db.mongo.query".freeze

      def normalize(trace, name, payload)
        # payload: { prefix: "  MOPED: #{address.resolved}", ops: operations }

        # We can sometimes have multiple operations. However, it seems like this only happens when doing things
        # like an insert, followed by a get last error, so we can probably ignore all but the first.
        operation = payload[:ops] ? payload[:ops].first : nil
        type = operation && operation.class.to_s =~ /^Moped::Protocol::(.+)$/ ? $1 : nil

        case type
        when "Query"       then normalize_query(operation)
        when "GetMore"     then normalize_get_more(operation)
        when "Insert"      then normalize_insert(operation)
        when "Update"      then normalize_update(operation)
        when "Delete"      then normalize_delete(operation)
        else :skip
        end
      end

    private

      def normalize_query(operation)
        title = normalize_title("QUERY", operation)

        hash, binds = extract_binds(operation.selector)
        description = hash.to_json

        annotations = build_annotations(operation)
        annotations[:skip] = operation.skip
        if operation.fields
          annotations[:fields] = operation.fields.select{|k,v| v == 1 }.keys.map(&:to_s)
        end
        annotations[:binds] = binds unless binds.empty?

        [CAT, title, description, annotations]
      end

      def normalize_get_more(operation)
        title = normalize_title("GET_MORE", operation)

        annotations = build_annotations(operation)
        annotations[:limit] = operation.limit

        [CAT, title, nil, annotations]
      end

      def normalize_insert(operation)
        title = normalize_title("INSERT", operation)

        annotations = build_annotations(operation)
        annotations[:count] = operation.documents.count

        [CAT, title, nil, annotations]
      end

      def normalize_update(operation)
        title = normalize_title("UPDATE", operation)

        selector_hash, selector_binds = extract_binds(operation.selector)
        update_hash, update_binds = extract_binds(operation.update)

        description = { selector: selector_hash, update: update_hash }.to_json

        annotations = build_annotations(operation)

        binds = {}
        binds[:selector] = selector_binds unless selector_binds.empty?
        binds[:update]   = update_binds   unless update_binds.empty?
        annotations[:binds] = binds unless binds.empty?

        [CAT, title, description, annotations]
      end

      def normalize_delete(operation)
        title = normalize_title("DELETE", operation)

        hash, binds = extract_binds(operation.selector)
        description = hash.to_json

        annotations = build_annotations(operation)
        annotations[:binds] = binds unless binds.empty?

        [CAT, title, description, annotations]
      end

      def normalize_title(type, operation)
        "#{type} #{operation.collection}"
      end

      def build_annotations(operation)
        annotations = {}

        if operation.respond_to?(:flags)
          flags = operation.flags.map{|f| flag_name(f) }
          annotations[:flags] = flags unless flags.empty?
        end

        annotations
      end

      # Some flags used by Moped don't map directly to the Mongo docs
      # See http://docs.mongodb.org/meta-driver/latest/legacy/mongodb-wire-protocol/
      FLAG_MAP = {
        tailable: "TailableCursor",
        multi:    "MultiUpdate"
      }

      def flag_name(flag)
        FLAG_MAP[flag] || flag.to_s.sub(/^[a-z\d]*/) { $&.capitalize }.gsub(/(?:_|(\/))([a-z\d]*)/) { "#{$1}#{$2.capitalize}" }
      end

      def extract_binds(hash, binds=[])
        hash = hash.dup

        hash.each do |k,v|
          if v.is_a?(Hash)
            hash[k] = extract_binds(v, binds)[0]
          else
            binds << stringify(hash[k])
            hash[k] = '?'
          end
        end

        [hash, binds]
      end

      def stringify(value)
        value.is_a?(Regexp) ? value.inspect : value.to_s
      end

    end
  end
end
