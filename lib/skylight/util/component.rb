# frozen_string_literal: true
require "uri"

module Skylight
  module Util
    class Component
      attr_accessor :environment, :name

      NAME_FORMAT = /\A[a-zA-Z0-9_-]+\z/
      DEFAULT_NAME = "web"
      WORKER_NAME = "worker"
      DEFAULT_ENVIRONMENT = "production"

      def initialize(environment, name, force_worker: false)
        @environment = environment || DEFAULT_ENVIRONMENT
        @name        = resolve_name(name, force_worker)

        raise ArgumentError, "environment can't be blank" if @environment.empty?
        validate_string!(@environment, "environment")
        validate_string!(@name, "name")
      end

      def to_s
        "#{name}:#{environment}"
      end

      def to_encoded_s
        @to_encoded_s ||= URI.encode_www_form_component(to_s)
      end

      def web?
        name == DEFAULT_NAME
      end

      def worker?
        !web?
      end

      # keys here should match those from the main config
      def as_json(*)
        {
          component: name,
          env: environment
        }
      end

      private

        def program_name
          $PROGRAM_NAME
        end

        def argv
          ARGV
        end

        def resolve_name(given_name, force_worker)
          # don't allow workers to be called 'web'
          return WORKER_NAME if force_worker && (given_name.nil? || given_name == DEFAULT_NAME)
          return DEFAULT_NAME if given_name.nil?

          given_name
        end

        def validate_string!(string, kind)
          return true if string =~ NAME_FORMAT
          raise ArgumentError, "#{kind} can only contain lowercase letters, numbers, and dashes"
        end
    end
  end
end
