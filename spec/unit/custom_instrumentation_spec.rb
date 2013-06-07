require 'spec_helper'

describe Skylight::Instrumenter, :http do

  let :hello do
    double('hello')
  end

  context 'when the instrumenter is not running' do

    it 'does not break code' do
      hello.should_receive(:hello)

      Skylight.trace 'Zomg', 'app.rack.request' do |t|
        t.should be_nil

        Skylight.instrument 'foo.bar' do |s|
          s.should be_nil
          hello.hello
        end
      end

      Skylight::Instrumenter.instance.should be_nil
    end

  end

  context 'when the instrumenter is running' do

    before :each do
      Skylight.start! config
      clock.freeze
    end

    after :each do
      Skylight.stop!
    end

    it 'tracks custom instrumentation metrics' do
      hello.should_receive(:hello)

      Skylight.trace 'Testin', 'app.rack.request' do |t|
        clock.skip 0.1
        Skylight.instrument 'app.foo' do
          clock.skip 0.1
          hello.hello
        end
      end

      clock.unfreeze
      server.wait

      server.reports[0].should have(1).endpoints

      ep = server.reports[0].endpoints[0]
      ep.name.should == 'Testin'
      ep.should have(1).traces

      t = ep.traces[0]
      t.should have(2).spans
      t.spans[0].should == span(
        event:      event('app.foo'),
        started_at: 1_000,
        duration:   1_000)
      t.spans[1].should == span(
        event:      event('app.rack.request'),
        started_at: 0,
        duration:   2_000,
        children:   1)
    end

    it 'recategorizes unknown events as other' do
      Skylight.trace 'Testin', 'app.rack.request' do |t|
        clock.skip 0.1
        Skylight.instrument 'foo' do
          clock.skip 0.1
        end
      end

      clock.unfreeze
      server.wait

      ep = server.reports[0].endpoints[0]
      t  = ep.traces[0]

      t.spans[0].should == span(
        event:      event('other.foo'),
        started_at: 1_000,
        duration:   1_000)
    end

  end

end
