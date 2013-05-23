require 'spec_helper'

module Skylight
  describe Messages::Trace do

    context 'defaults' do

      it 'defaults endpoint to unknown' do
        trace.endpoint.should == 'Unknown'
      end

      it 'defaults the start time to now' do
        Util::Clock.default.
          should_receive(:now).
          and_return(1000)

        trace.record(1002, "foo", nil, nil, nil)
        trace.spans[0].started_at.should == 20_000
      end

    end

    context 'building' do

      let :trace do
        Messages::Trace::Builder.new 'Zomg', 10
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
        span.event.category.should   == 'foo'
        span.started_at.should == 10_000
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
        trace.build

        trace.spans.should have(5).item

        span(0).event.category.should == 'cat4'
        span(0).started_at.should     == 10_000
        span(0).duration.should       be_nil
        span(0).children.should       be_nil

        span(1).event.category.should == 'cat5'
        span(1).started_at.should     == 30_000
        span(1).duration.should       be_nil
        span(1).children.should       be_nil

        span(2).event.category.should == 'cat3'
        span(2).started_at.should     == 0
        span(2).duration.should       == 30_000
        span(2).children.should       == 2

        span(3).event.category.should == 'cat2'
        span(3).started_at.should     == 10_000
        span(3).duration.should       == 60_000
        span(3).children.should       == 1

        span(4).event.category.should == 'cat1'
        span(4).started_at.should     == 0
        span(4).duration.should       == 90_000
        span(4).children.should       == 1
      end

      it 'raises an exception on stop when the trace is unbalanced' do
        lambda {
          trace.stop 10
        }.should raise_error(TraceError)
      end

      it 'raises an exception on commit when the trace is unbalanced' do
        trace.start 10, :foo
        lambda {
          trace.build
        }.should raise_error(TraceError)
      end

      it 'tracks the title' do
        trace.start  10, :foo, 'How a foo is formed?'
        trace.record 13, :bar, 'How a bar is formed?'
        trace.stop   15
        trace.build

        span(0).event.title.should == 'How a bar is formed?'
        span(1).event.title.should == 'How a foo is formed?'
      end

      it 'tracks the description' do
        trace.start  10, :foo, 'FOO', 'How a foo is formed?'
        trace.record 13, :bar, 'BAR', 'How a bar is formed?'
        trace.stop   15

        span(0).event.title.should       == 'BAR'
        span(0).event.description.should == 'How a bar is formed?'
        span(1).event.title.should       == 'FOO'
        span(1).event.description.should == 'How a foo is formed?'
      end

    end

  end
end
