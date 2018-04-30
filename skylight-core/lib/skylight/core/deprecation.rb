require 'active_support/deprecation'

module Skylight::Core
  SKYLIGHT_GEM_ROOT = File.expand_path("../../..", __FILE__) + "/"

  class Deprecation < ActiveSupport::Deprecation
    private

      def ignored_callstack(path)
        path.start_with?(SKYLIGHT_GEM_ROOT)
      end
  end

  DEPRECATOR = Deprecation.new('3.0', 'skylight-core')
end