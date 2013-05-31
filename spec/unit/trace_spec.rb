require 'spec_helper'

module Skylight
  describe Messages::Trace do

    context 'defaults' do

      it 'defaults endpoint to unknown' do
        trace.endpoint.should == 'Unknown'
      end

      it 'defaults the start time to now' do
        clock.now = 1000

        trace.record(2_001_000, "foo", nil, nil, nil)
        trace.spans[0].started_at.should == 20_000
      end

    end

    context 'building' do

      let :trace do
        Messages::Trace::Builder.new 'Zomg', 1000, config
      end

      it 'does not track the span when it is started' do
        trace.start(2000, 'foo', :foo)
        trace.spans.should be_empty
      end

      it 'tracks the span when it is finished' do
        trace.start(2000, 'foo', :foo)
        trace.stop(3000, 'foo')

        trace.spans.should have(1).item
        span = trace.spans[0]
        span.event.category.should   == 'foo'
        span.started_at.should == 10
      end

      it 'builds the trace' do
        trace.start  1000,   'cat1', :cat1
        trace.start  2000,   'cat2', :cat2
        trace.start  2000,   'lulz', :skip
        trace.start  2000,   'cat3', :cat3
        trace.start  3000,   'gree', :skip
        trace.record 3000,   :cat4
        trace.stop   4000,   'gree'
        trace.record 5000,   :cat5
        trace.stop   5000,   'cat3'
        trace.stop   6000,   'lulz'
        trace.stop   8000,   'cat2'
        trace.stop   10_000, 'cat1'
        trace.build

        trace.spans.should have(5).item

        span(0).event.category.should == 'cat4'
        span(0).started_at.should     == 10
        span(0).duration.should       be_nil
        span(0).children.should       be_nil

        span(1).event.category.should == 'cat5'
        span(1).started_at.should     == 30
        span(1).duration.should       be_nil
        span(1).children.should       be_nil

        span(2).event.category.should == 'cat3'
        span(2).started_at.should     == 0
        span(2).duration.should       == 30
        span(2).children.should       == 2

        span(3).event.category.should == 'cat2'
        span(3).started_at.should     == 10
        span(3).duration.should       == 60
        span(3).children.should       == 1

        span(4).event.category.should == 'cat1'
        span(4).started_at.should     == 0
        span(4).duration.should       == 90
        span(4).children.should       == 1
      end

      it 'handles clock skew' do
        trace.start 1000, 'cat1', :cat1
        trace.start 900,  'cat2', :cat2
        trace.stop  1100, 'cat2'
        trace.stop  1000, 'cat1'
        trace.build

        trace.spans.should have(2).item

        span(0).started_at.should == 0
        span(0).duration.should == 1

        span(1).started_at.should == 0
        span(1).duration.should == 1
      end

      it 'raises an exception on stop when the trace is unbalanced' do
        lambda {
          trace.stop 10, 'foo'
        }.should raise_error(TraceError)
      end

      it 'raises an exception on commit when the trace is unbalanced' do
        trace.start 1000, 'foo', :foo
        lambda {
          trace.build
        }.should raise_error(TraceError, /remaining/)
      end

      it 'raises an exception on commit when the trace is unbalanced' do
        trace.start 1000, 'foo', :foo
        trace.start 2000, 'lulz', :skip

        lambda {
          trace.build
        }.should raise_error(TraceError, /foo.*lulz/)
      end

      it 'does not raise an exception when root throws an error' do
        lambda {
          trace.root 'zomg' do
            trace.start 1000, 'foo', :foo
          end
        }.should_not raise_error(TraceError)
      end

      it 'tracks the title' do
        trace.start  1000, 'foo', :foo, 'How a foo is formed?'
        trace.record 3000, :bar, 'How a bar is formed?'
        trace.stop   5000, 'foo'
        trace.build

        span(0).event.title.should == 'How a bar is formed?'
        span(1).event.title.should == 'How a foo is formed?'
      end

      it 'tracks the description' do
        trace.start  1000, 'foo', :foo, 'FOO', 'How a foo is formed?'
        trace.record 3000, :bar, 'BAR', 'How a bar is formed?'
        trace.stop   5000, 'foo'

        span(0).event.title.should       == 'BAR'
        span(0).event.description.should == 'How a bar is formed?'
        span(1).event.title.should       == 'FOO'
        span(1).event.description.should == 'How a foo is formed?'
      end

    end

  end
end
