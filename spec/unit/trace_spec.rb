require 'spec_helper'

module Skylight
  describe "Messages::Trace", :agent do

    before :each do
      clock.now = 100_000_000
    end

    let! :trace do
      Skylight::Messages::Trace::Builder.new instrumenter, 'Zomg', clock.nanos, 'app.rack.request'
    end

    it 'does not track the span when it is started' do
      trace.instrument 'foo' do
        trace.spans.should be_empty
      end
    end

    def spans
      serialized.spans
    end

    def serialized
      @serialized ||= SpecHelper::Messages::Trace.decode(trace.serialize)
    end

    it 'tracks the span when it is finished' do
      clock.skip 0.1
      a = trace.instrument 'foo'
      clock.skip 0.1
      trace.done(a)
      trace.traced

      spans.should have(2).items
      spans[0].event.category.should == 'app.rack.request'
      spans[1].event.category.should == 'foo'
      spans[0].started_at.should == 0
      spans[1].started_at.should == 1000
    end

    it 'builds the trace' do
      a = trace.instrument 'cat1', { foo: "bar" }
      clock.skip 0.001
      b = trace.instrument 'cat2'
      c = trace.instrument 'cat3'
      clock.skip 0.001
      trace.record 'cat4'
      clock.skip 0.002
      trace.record 'cat5'
      trace.done(c)
      clock.skip 0.003
      trace.done(b)
      clock.skip 0.002
      trace.done(a)
      trace.traced

      spans.should have(6).items

      spans[0].event.category.should == 'app.rack.request'
      spans[0].started_at.should     == 0
      spans[0].parent.should         == nil
      spans[0].duration.should       == 90

      spans[1].event.category.should == 'cat1'
      spans[1].started_at.should     == 0
      spans[1].parent.should         == 0
      spans[1].duration.should       == 90

      spans[2].event.category.should == 'cat2'
      spans[2].started_at.should     == 10
      spans[2].parent.should         == 1
      spans[2].duration.should       == 60

      spans[3].event.category.should == 'cat3'
      spans[3].started_at.should     == 0
      spans[3].parent.should         == 2
      spans[3].duration.should       == 30

      spans[4].event.category.should == 'cat4'
      spans[4].started_at.should     == 10
      spans[4].parent.should         == 3
      spans[4].duration.should       == 0

      spans[5].event.category.should == 'cat5'
      spans[5].started_at.should     == 30
      spans[5].parent.should         == 3
      spans[5].duration.should       == 0
    end

    it 'force closes any open span on build' do
      trace.instrument 'foo'
      clock.skip 0.001
      trace.traced

      spans.should have(2).items
      spans[1].event.category.should == 'foo'
      spans[1].started_at.should == 0
      spans[1].duration.should == 10

      spans[0].event.category.should == 'app.rack.request'
    end

    it 'closes any spans that were not properly closed' do
      a = trace.instrument 'foo'
      clock.skip 0.1
      b = trace.instrument 'bar'
      clock.skip 0.1
      trace.instrument 'baz'
      clock.skip 0.1
      trace.done(a)
      clock.skip 0.1
      trace.done(b)
      clock.skip 0.1

      trace.traced

      spans.should have(4).items

      spans[0].event.category.should == 'app.rack.request'
      spans[0].duration.should       == 4000

      spans[1].event.category.should == 'foo'
      spans[1].duration.should       == 3000

      spans[2].event.category.should == 'bar'
      spans[2].duration.should       == 2000

      spans[3].event.category.should == 'baz'
      spans[3].duration.should       == 1000
    end

    it 'tracks the title' do
      a = trace.instrument 'foo', 'How a foo is formed?'
      trace.record :bar, 'How a bar is formed?'
      trace.done(a)
      trace.traced

      spans[1].event.title.should == 'How a foo is formed?'
      spans[2].event.title.should == 'How a bar is formed?'
    end

    it 'tracks the description' do
      a = trace.instrument 'foo', 'FOO', 'How a foo is formed?'
      trace.record :bar, 'BAR', 'How a bar is formed?'
      trace.done(a)
      trace.traced

      spans[1].event.title.should       == 'FOO'
      spans[1].event.description.should == 'How a foo is formed?'
      spans[2].event.title.should       == 'BAR'
      spans[2].event.description.should == 'How a bar is formed?'
    end

    it 'limits unique descriptions' do
      def instrumenter.limited_description(desc)
        return Skylight::Instrumenter::TOO_MANY_UNIQUES
      end

      a = trace.instrument 'foo', 'FOO', 'How a foo is formed?'
      trace.record :bar, 'BAR', 'How a bar is formed?'
      trace.done(a)
      trace.traced

      spans[1].event.title.should       == 'FOO'
      spans[1].event.description.should == Skylight::Instrumenter::TOO_MANY_UNIQUES
      spans[2].event.title.should       == 'BAR'
      spans[2].event.description.should == Skylight::Instrumenter::TOO_MANY_UNIQUES
    end
  end

end
