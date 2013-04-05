require 'spec_helper'

# I'm not very satisfied with these tests.
# I suspect these are too specific for true integration tests.
# - Peter

module Skylight
  describe Middleware, :type => :feature do
    let :middleware do
      Rails.application.middleware.first
    end

    it "is the first middleware" do
      middleware.should == Middleware
    end
  end
end
