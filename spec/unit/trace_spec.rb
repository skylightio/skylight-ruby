require 'spec_helper'

module Skylight
  describe Trace do

    context 'defaults' do

      it 'defaults endpoint to unknown' do
        trace.endpoint.should == 'Unknown'
      end

      it 'defaults the start time to now' do
        Util::Clock.default.
          should_receive(:now).
          and_return(1000)

        trace.record(1002, "foo", nil, nil, nil)
        trace.spans[0].started_at.should == 2_000_000
      end

    end

    context 'building' do

      let :trace do
        Trace.new 'Zomg', 10
      end

      it 'does not track the span when it is started' do
        trace.start(11, :foo)
        trace.spans.should be_empty
      end

      it 'tracks the span when it is finished' do
        trace.start(11, :foo)
        trace.stop(12)

        trace.spans.should have(1).item
        span = trace.spans[0]
        span.category.should   == 'foo'
        span.started_at.should == 1_000_000
      end

      it 'builds the trace' do
        trace.start  10, :cat1
        trace.start  11, :cat2
        trace.start  11, :skip
        trace.start  11, :cat3
        trace.start  12, :skip
        trace.record 12, :cat4
        trace.stop   13
        trace.record 14, :cat5
        trace.stop   14
        trace.stop   15
        trace.stop   17
        trace.stop   19
        trace.commit

        trace.spans.should have(5).item

        span(0).category.should   == 'cat4'
        span(0).started_at.should == 2_000_000
        span(0).children.should   be_nil

        span(1).category.should   == 'cat5'
        span(1).started_at.should == 4_000_000
        span(1).children.should   be_nil

        span(2).category.should   == 'cat3'
        span(2).started_at.should == 1_000_000
        span(2).children.should   == 2

        span(3).category.should   == 'cat2'
        span(3).started_at.should == 1_000_000
        span(3).children.should   == 1

        span(4).category.should   == 'cat1'
        span(4).started_at.should == 0
        span(4).children.should   == 1
      end

    end

  end
end
