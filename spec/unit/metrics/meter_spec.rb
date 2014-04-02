require 'spec_helper'

module Skylight
  module Metrics
    describe Meter do

      before :each do
        clock.freeze
      end

      let :meter do
        Meter.new EWMA.one_minute_ewma, clock
      end

      context 'during first tick' do

        it 'has a rate of 0 when uninitialized' do
          meter.rate.should == 0
        end

        it 'has a rate of 0 when initialized' do
          meter.mark 23
          meter.rate.should == 0
        end
      end

      context 'during second tick' do

        it 'has a rate of the instant value during the first tick' do
          meter.mark 25

          clock.skip 5
          meter.rate.should == 5

          meter.mark 5
          meter.rate.should == 5
        end
      end

      context 'during the next tick' do

        it 'tracks the EWMA' do
          meter.mark 25

          clock.skip 5

          meter.mark 3
          meter.mark 10
          meter.mark 30

          clock.skip 5

          meter.rate.should be_within(0.0001).of(5.28784)
          meter.mark 100

          clock.skip 10

          meter.rate.should be_within(0.0001).of(5.94731)
        end
      end
    end
  end
end
