module Skylight
  module CLI
    module Helpers

      private

      # Duplicated below
      def rails_rb
        File.expand_path("config/application.rb")
      end

      def is_rails?
        File.exist?(rails_rb)
      end

      def config
        # Calling .load checks ENV variables
        @config ||= Config.load
      end

      # Sets the output padding while executing a block and resets it.
      #
      def indent(count = 1, &block)
        orig_padding = shell.padding
        shell.padding += count
        yield
        shell.padding = orig_padding
      end

    end
  end
end