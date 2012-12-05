require 'spec_helper'

module Skylight
  describe Middleware, :type => :feature do
    it "is included" do
      Rails.application.middleware.should include(Middleware)
    end
  end
end
