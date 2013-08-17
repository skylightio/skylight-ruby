require 'spec_helper'

module Skylight
  describe Messages::Trace do

    before :each do
      clock.now = 1000
    end

    let! :trace do
      Skylight::Messages::Trace::Builder.new instrumenter, 'Zomg', 1000, 'app.rack.request'
    end

    it 'does not track the span when it is started' do
      trace.instrument 'foo' do
        trace.spans.should be_empty
      end
    end

    it 'tracks the span when it is finished' do
      clock.skip 0.1
      a = trace.instrument 'foo'
      clock.skip 0.1
      a.done

      trace.spans.should have(1).item
      span(0).event.category.should   == 'foo'
      span(0).started_at.should == 1000
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
      c.done
      clock.skip 0.003
      b.done
      clock.skip 0.002
      a.done
      trace.submit

      trace.spans.should have(6).item

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
      span(4).annotations.should    == [annotation("foo", :string, "bar")]

      span(5).event.category.should == 'app.rack.request'
    end

    it 'handles clock skew' do
      a = trace.instrument 'cat1'
      clock.skip(-0.001)
      b = trace.instrument 'cat2'
      clock.skip 0.002
      b.done
      clock.skip(-0.001)
      a.done
      trace.submit

      trace.spans.should have(3).item

      span(0).started_at.should == 0
      span(0).duration.should == 10

      span(1).started_at.should == 0
      span(1).duration.should == 10

      span(2).event.category.should == 'app.rack.request'
    end

    it 'force closes any open span on build' do
      trace.instrument 'foo'
      clock.skip 0.001
      trace.submit

      trace.should have(2).spans
      span(0).event.category.should == 'foo'
      span(0).started_at.should == 0
      span(0).duration.should == 10

      span(1).event.category.should == 'app.rack.request'
    end

    it 'closes any spans that were not properly closed' do
      a = trace.instrument 'foo'
      clock.skip 0.1
      b = trace.instrument 'bar'
      clock.skip 0.1
      trace.instrument 'baz'
      clock.skip 0.1
      a.done
      clock.skip 0.1
      b.done
      clock.skip 0.1

      trace.submit
      trace.should have(4).spans

      span(0).event.category.should == 'baz'
      span(0).duration.should == 1000

      span(1).event.category.should == 'bar'
      span(1).duration.should == 2000

      span(2).event.category.should == 'foo'
      span(2).duration.should == 3000

      span(3).event.category.should == 'app.rack.request'
    end

    it 'tracks the title' do
      a = trace.instrument 'foo', 'How a foo is formed?'
      trace.record :bar, 'How a bar is formed?'
      a.done
      trace.submit

      span(0).event.title.should == 'How a bar is formed?'
      span(1).event.title.should == 'How a foo is formed?'
    end

    it 'tracks the description' do
      a = trace.instrument 'foo', 'FOO', 'How a foo is formed?'
      trace.record :bar, 'BAR', 'How a bar is formed?'
      a.done
      trace.submit

      span(0).event.title.should       == 'BAR'
      span(0).event.description.should == 'How a bar is formed?'
      span(1).event.title.should       == 'FOO'
      span(1).event.description.should == 'How a foo is formed?'
    end

  end

end
