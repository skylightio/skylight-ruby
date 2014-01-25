module Skylight
  class Hello
    DIGITS = /^\s*\d+\s*$/

    alias serialize native_serialize
    alias version native_get_version

    class << self
      alias deserialize native_load
    end

    def cmd
      native_cmd_length.times.map do |offset|
        native_cmd_get(offset)
      end
    end

    def newer?(other = VERSION)
      other = split(other)
      curr  = split(version)

      [other.length, curr.length].max.times do |i|
        next if other[i] == curr[i]
        return true unless other[i]

        if other[i] =~ DIGITS
          if curr[i] =~ DIGITS
            other_i = other[i].to_i
            curr_i = curr[i].to_i

            next if other_i == curr_i

            return curr_i > other_i
          else
            return false
          end
        else
          if curr[i] =~ DIGITS
            return true
          else
            next if curr[i] == other[i]
            return curr[i] > other[i]
          end
        end
      end

      false
    end

    private

      def split(v)
        v.split('.')
      end

  end

  class Error
    alias serialize native_serialize
    alias type native_get_group
    alias description native_get_description
    alias details native_get_details

    class << self
      alias deserialize native_load
    end
  end

  class Trace
    alias serialize native_serialize

    class << self
      alias deserialize native_load
    end
  end

  class Batch
    alias serialize native_serialize
  end
end
