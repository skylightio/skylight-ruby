require 'skylight/messages/base'

module Skylight
  module Messages
    class Hello < Base

      DIGITS = /^\s*\d+\s*$/

      required :version, :string, 1
      optional :config,  :uint32, 2
      repeated :cmd,     :string, 3

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
  end
end
