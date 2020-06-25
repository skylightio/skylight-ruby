# frozen_string_literal: true

require "active_support/core_ext/string"

module SpecHelper
  module Messages
    module MessageDig
      def dig(*args)
        head, *tail = args
        return self unless head

        self[head]&.dig(*tail)
      end
    end
  end
end

%w[annotation event span trace endpoint batch].each do |message|
  require(File.expand_path("../messages/#{message}", __FILE__))

  SpecHelper::Messages.const_get(message.camelize).instance_exec do
    include SpecHelper::Messages::MessageDig
  end
end
