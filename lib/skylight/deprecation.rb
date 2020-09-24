# frozen_string_literal: true

require "active_support/deprecation"

module Skylight
  SKYLIGHT_GEM_ROOT = "#{File.expand_path('../..', __dir__)}/"

  class Deprecation < ActiveSupport::Deprecation
    private

      def ignored_callstack(path)
        path.start_with?(SKYLIGHT_GEM_ROOT)
      end
  end

  DEPRECATOR = Deprecation.new("6.0", "skylight")
end
