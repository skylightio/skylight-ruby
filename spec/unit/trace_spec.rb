require 'spec_helper'

module Skylight
  describe Trace, :http, :agent do

    before :each do
      clock.tick = 100_000_000
      start!
    end

    after :each do
      Skylight.stop!
    end

    it 'tracks the span when it is finished' do
      trace = Skylight.trace 'Rack', 'app.rack.request'
      clock.skip 0.1
      a = trace.instrument 'foo'
      clock.skip 0.1
      trace.done(a)
      trace.submit

      server.wait resource: '/report'

      expect(spans.count).to eq(2)
      expect(spans[0].event.category).to eq('app.rack.request')
      expect(spans[1].event.category).to eq('foo')
      expect(spans[0].started_at).to eq(0)
      expect(spans[1].started_at).to eq(1000)
    end

    it 'builds the trace' do
      trace = Skylight.trace 'Rack', 'app.rack.request'
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
      trace.submit

      server.wait resource: '/report'

      expect(spans.count).to eq(6)

      expect(spans[0].event.category).to eq('app.rack.request')
      expect(spans[0].started_at).to     eq(0)
      expect(spans[0].parent).to         eq(nil)
      expect(spans[0].duration).to       eq(90)

      expect(spans[1].event.category).to eq('cat1')
      expect(spans[1].started_at).to     eq(0)
      expect(spans[1].parent).to         eq(0)
      expect(spans[1].duration).to       eq(90)

      expect(spans[2].event.category).to eq('cat2')
      expect(spans[2].started_at).to     eq(10)
      expect(spans[2].parent).to         eq(1)
      expect(spans[2].duration).to       eq(60)

      expect(spans[3].event.category).to eq('cat3')
      expect(spans[3].started_at).to     eq(0)
      expect(spans[3].parent).to         eq(2)
      expect(spans[3].duration).to       eq(30)

      expect(spans[4].event.category).to eq('cat4')
      expect(spans[4].started_at).to     eq(10)
      expect(spans[4].parent).to         eq(3)
      expect(spans[4].duration).to       eq(0)

      expect(spans[5].event.category).to eq('cat5')
      expect(spans[5].started_at).to     eq(30)
      expect(spans[5].parent).to         eq(3)
      expect(spans[5].duration).to       eq(0)
    end

    it 'force closes any open span on build' do
      trace = Skylight.trace 'Rack', 'app.rack.request'
      trace.instrument 'foo'
      clock.skip 0.001
      trace.submit

      server.wait resource: '/report'

      expect(spans.count).to eq(2)
      expect(spans[1].event.category).to eq('foo')
      expect(spans[1].started_at).to eq(0)
      expect(spans[1].duration).to eq(10)

      expect(spans[0].event.category).to eq('app.rack.request')
    end

    it 'closes any spans that were not properly closed' do
      trace = Skylight.trace 'Rack', 'app.rack.request'
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
      trace.submit

      server.wait resource: '/report'

      expect(spans.count).to eq(4)

      expect(spans[0].event.category).to eq('app.rack.request')
      expect(spans[0].duration).to       eq(4000)

      expect(spans[1].event.category).to eq('foo')
      expect(spans[1].duration).to       eq(3000)

      expect(spans[2].event.category).to eq('bar')
      expect(spans[2].duration).to       eq(2000)

      expect(spans[3].event.category).to eq('baz')
      expect(spans[3].duration).to       eq(1000)
    end

    it 'tracks the title' do
      trace = Skylight.trace 'Rack', 'app.rack.request'
      a = trace.instrument 'foo', 'How a foo is formed?'
      trace.record :bar, 'How a bar is formed?'
      trace.done(a)
      trace.submit

      server.wait resource: '/report'

      expect(spans[1].event.title).to eq('How a foo is formed?')
      expect(spans[2].event.title).to eq('How a bar is formed?')
    end

    it 'tracks the description' do
      trace = Skylight.trace 'Rack', 'app.rack.request'
      a = trace.instrument 'foo', 'FOO', 'How a foo is formed?'
      trace.record :bar, 'BAR', 'How a bar is formed?'
      trace.done(a)
      trace.submit

      server.wait resource: '/report'

      expect(spans[1].event.title).to       eq('FOO')
      expect(spans[1].event.description).to eq('How a foo is formed?')
      expect(spans[2].event.title).to       eq('BAR')
      expect(spans[2].event.description).to eq('How a bar is formed?')
    end

    it 'limits unique descriptions' do
      trace = Skylight.trace 'Rack', 'app.rack.request'

      expect(Skylight::Instrumenter.instance).to receive(:limited_description).
        at_least(:once).
        with(any_args()).
        and_return(Skylight::Instrumenter::TOO_MANY_UNIQUES)

      a = trace.instrument 'foo', 'FOO', 'How a foo is formed?'
      trace.record :bar, 'BAR', 'How a bar is formed?'
      trace.done(a)
      trace.submit

      server.wait resource: '/report'

      expect(spans[1].event.title).to       eq('FOO')
      expect(spans[1].event.description).to eq(Skylight::Instrumenter::TOO_MANY_UNIQUES)
      expect(spans[2].event.title).to       eq('BAR')
      expect(spans[2].event.description).to eq(Skylight::Instrumenter::TOO_MANY_UNIQUES)
    end

    def spans
      server.reports[0].endpoints[0].traces[0].spans
    end
  end
end
