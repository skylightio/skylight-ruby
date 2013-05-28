require 'spec_helper'

module Skylight
  describe GC, :http do

    let :instrumenter do
      Skylight::Instrumenter.new config
    end

    before :each do
      clock.freeze
      instrumenter.start!
    end

    after :each do
      instrumenter.shutdown
    end

    context 'when there is no GC and no spans' do

      it 'leaves the GC node out' do
        gc.should_receive(:total_time).and_return(0)

        instrumenter.trace 'Rack' do |t|
          t.root 'app.rack' do
            clock.skip 1
          end
        end

        clock.unfreeze
        server.wait

        trace.should have(1).spans
        trace.spans[0].duration.should == 10_000
      end

    end

    context 'when there is GC and no spans' do

      it 'adds a GC node' do
        gc.should_receive(:total_time).and_return(0.1)
        gc.should_receive(:clear)

        instrumenter.trace 'Rack' do |t|
          t.root 'app.rack' do
            clock.skip 1
          end
        end

        clock.unfreeze
        server.wait

        trace.should have(2).spans
        span(1).duration.should == 10_000

        span(0).event.category.should == 'noise.gc'
        span(0).duration.should == 1_000
      end

    end

    context 'when there is GC and a span' do

      it 'subtracts GC from the span and adds it at the end' do
        gc.should_receive(:total_time).exactly(3).times.and_return(0, 0.1, 0)
        gc.should_receive(:clear)

        instrumenter.trace 'Rack' do |t|
          t.root 'app.rack' do
            instrument 'app.test' do
              clock.skip 1
            end
          end
        end

        clock.unfreeze
        server.wait

        trace.should have(3).spans
        span(0).event.category.should == 'app.test'
        span(0).duration.should == 9_000

        span(1).event.category.should == 'noise.gc'
        span(1).duration.should == 1_000

        span(2).event.category.should == 'app.rack'
        span(2).duration.should == 10_000
      end
    end

    def trace
      server.reports[0].endpoints[0].traces[0]
    end

  end
end
