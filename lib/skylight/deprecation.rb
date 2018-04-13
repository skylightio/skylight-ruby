require 'active_support/deprecation'

module Skylight
  if ActiveSupport::Deprecation.respond_to?(:new)
    DEPRECATOR = ActiveSupport::Deprecation.new('2.0', 'skylight')
  else
    # Rails 3.x
    DEPRECATOR = Module.new do
      class << self
        attr_accessor :silenced

        # Silence deprecation warnings within the block.
        def silence
          old_silenced, @silenced = @silenced, true
          yield
        ensure
          @silenced = old_silenced
        end

        def deprecation_warning(msg)
          return if silenced
          ActiveSupport::Deprecation.warn("#{msg} is deprecated and will be removed from skylight 2.0", extract_callstack(caller))
        end

        private

        def extract_callstack(callstack)
          skylight_gem_root = File.expand_path("../../../..", __FILE__) + "/"
          filtered = callstack.reject { |line| line.start_with?(skylight_gem_root) }
          filtered.empty? ? callstack : filtered
        end
      end
    end
  end
end
