require 'socket'
require 'securerandom'

module Skylight
  module Util
    module Hostname
      def self.default_hostname
        if hostname = Socket.gethostname
          hostname.strip!
          hostname = nil if hostname == ''
        end

        hostname || "gen-#{SecureRandom.uuid}"
      end
    end
  end
end
