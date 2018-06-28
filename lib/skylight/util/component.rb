module Skylight
  module Util
    class Component

      attr_accessor :environment, :name

      NAME_FORMAT = /\A[a-z0-9-]+\z/
      DEFAULT_NAME = 'web'.freeze
      DEFAULT_ENVIRONMENT = 'production'.freeze

      def initialize(environment, name)
        @environment = environment || DEFAULT_ENVIRONMENT
        @name        = name || DEFAULT_NAME

        raise ArgumentError, "environment can't be blank" if @environment.empty?
        validate_string!(@environment, 'environment')
        validate_string!(@name, 'name')
      end

      def to_s
        "#{name}:#{environment}"
      end

      private

      def validate_string!(string, kind)
        return true if string =~ NAME_FORMAT
        raise ArgumentError, "#{kind} can only contain lowercase letters, numbers, and dashes"
      end
    end
  end
end
