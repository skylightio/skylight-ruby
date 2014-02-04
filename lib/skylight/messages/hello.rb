module Skylight
  module Messages
    class Hello
      def self.build(version, cmd=[])
        Skylight::Hello.native_new(version, 0).tap do |hello|
          cmd.each { |part| hello.native_add_cmd_part(part) }
        end
      end

    end
  end
end
