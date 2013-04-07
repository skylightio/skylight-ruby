module Skylight
  module Normalize
    class StartProcessing < Normalizer
      register "start_processing.action_controller"

      def normalize
        return :skip
      end
    end
  end
end

