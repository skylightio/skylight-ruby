require 'active_support/deprecation'

module Skylight
  SKYLIGHT_GEM_ROOT = File.expand_path("../../..", __FILE__) + "/"

  if ActiveSupport::Deprecation.respond_to?(:new)
    class Deprecation < ActiveSupport::Deprecation
      private

        def ignored_callstack(path)
          path.start_with?(SKYLIGHT_GEM_ROOT)
        end
    end
  else
    # Rails 3.x
    class Deprecation
      attr_accessor :silenced
      attr_reader :deprecation_horizon, :gem_name

      def initialize(deprecation_horizon, gem_name)
        @deprecation_horizon = deprecation_horizon
        @gem_name = gem_name
      end

      # Silence deprecation warnings within the block.
      def silence
        old_silenced, @silenced = @silenced, true
        yield
      ensure
        @silenced = old_silenced
      end

      def deprecation_warning(deprecated_method_name, message = nil)
        return if silenced

        msg = "#{deprecated_method_name} is deprecated and will be removed from #{gem_name} #{deprecation_horizon}"
        case message
          when Symbol then msg << " (use #{message} instead)"
          when String then msg << " (#{message})"
        end

        ActiveSupport::Deprecation.warn(msg, extract_callstack(caller))
      end

      private

        def extract_callstack(callstack)
          filtered = callstack.reject { |line| line.start_with?(SKYLIGHT_GEM_ROOT) }
          filtered.empty? ? callstack : filtered
        end
    end
  end

  DEPRECATOR = Deprecation.new('2.0', 'skylight')
end
