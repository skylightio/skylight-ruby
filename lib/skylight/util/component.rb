module Skylight
  module Util
    class Component

      TYPES = %w(web worker).map(&:freeze).freeze

      attr_accessor :environment, :type

      def initialize(environment, type)
        @environment = environment
        raise ArgumentError, "environment can't be blank" if environment.nil? || environment.empty?
        unless environment =~ /^[\w\d-]+$/
          raise ArgumentError, "environment can only contain letters, numbers, and dashes"
        end
        @type = type
        unless TYPES.include?(type)
          raise ArgumentError, "type is invalid; expected one of [#{TYPES.inspect}] but got #{type}"
        end
      end

      def to_s
        "#{environment}:#{type}"
      end

    end
  end
end
