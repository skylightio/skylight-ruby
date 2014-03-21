require 'spec_helper'

module Skylight
  describe GC, :http do

    before :each do
      clock.freeze
    end

    after :each do
      Skylight.stop!
    end

    context 'when there is no GC and no spans' do

      it 'leaves the GC node out' do
        start!

        gc.should be_enabled
        gc.should_receive(:total_time).
          exactly(2).times.and_return(0.0, 0.0)

        Skylight.trace 'Rack', 'app.rack' do |t|
          clock.skip 1
        end

        clock.unfreeze
        server.wait count: 3

        trace.should have(1).spans
        trace.spans[0].duration.should == 10_000
      end

    end

    context 'when there is GC and no spans' do

      it 'adds a GC node' do
        start!

        gc.should be_enabled
        gc.should_receive(:total_time).
          exactly(2).times.and_return(0.0, 100_000_000)

        Skylight.trace 'Rack', 'app.rack' do |t|
          clock.skip 1
        end

        clock.unfreeze
        server.wait count: 3

        trace.should have(2).spans
        span(0).duration.should == 10_000

        span(1).event.category.should == 'noise.gc'
        span(1).duration.should == 1_000
      end

    end

    context 'when there is GC and a span' do

      it 'subtracts GC from the span and adds it at the end' do
        start!

        gc.should be_enabled
        gc.should_receive(:total_time).
          exactly(4).times.and_return(0, 0, 100_000_000, 0)

        Skylight.trace 'Rack', 'app.rack' do |t|
          instrument 'app.test' do
            clock.skip 1
          end
        end

        clock.unfreeze
        server.wait count: 3

        trace.should have(3).spans

        span(0).event.category.should == 'app.rack'
        span(0).duration.should == 10_000

        span(1).event.category.should == 'app.test'
        span(1).duration.should == 9_000

        span(2).event.category.should == 'noise.gc'
        span(2).duration.should == 1_000
      end
    end

    def trace
      server.reports[0].endpoints[0].traces[0]
    end

  end
end
