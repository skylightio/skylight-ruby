module Gen
  class Basic
    def initialize
      @controllers = %w(WidgetsController FoobarsController)
      @actions     = %w(index show)
    end

    def gen
      controller do
        sleep 0.4
      end
    end

  private

    def controller(&blk)
      instrument("process_action.action_controller",
        controller: @controllers.sample,
        action: @actions.sample,
        &blk)
    end

    def instrument(*args, &blk)
      ActiveSupport::Notifications.instrument(*args, &blk)
    end
  end
end
