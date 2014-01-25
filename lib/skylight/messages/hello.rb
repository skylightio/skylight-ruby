require 'skylight/messages/base'

module Skylight
  module Messages
    class Hello < Base

      required :version, :string, 1
      optional :config,  :uint32, 2
      repeated :cmd,     :string, 3

      def self.build(version, cmd=[])
        Skylight::Hello.native_new(version, 0).tap do |hello|
          cmd.each { |part| hello.native_add_cmd_part(part) }
        end
      end

    end
  end
end
