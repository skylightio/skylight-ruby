require 'spec_helper'

describe "Skylight::Instrumenter", :http, :agent do

  let :hello do
    double('hello')
  end

  context 'when the instrumenter is not running' do

    it 'does not break code' do
      hello.should_receive(:hello)

      Skylight.trace 'Zomg', 'app.rack.request' do |t|
        t.should be_nil

        ret = Skylight.instrument category: 'foo.bar' do |s|
          s.should be_nil
          hello.hello
          1
        end

        ret.should == 1
      end

      Skylight::Instrumenter.instance.should be_nil
    end

  end

  context 'when the instrumenter is running' do

    before :each do
      start!
      clock.freeze
    end

    after :each do
      Skylight.stop!
    end

    it 'tracks custom instrumentation metrics' do
      hello.should_receive(:hello)

      Skylight.trace 'Testin', 'app.rack.request' do |t|
        clock.skip 0.1
        ret = Skylight.instrument category: 'app.foo' do
          clock.skip 0.1
          hello.hello
          3
        end

        ret.should == 3
      end

      clock.unfreeze
      server.wait(count: 3)

      server.reports[0].endpoints.count.should == 1

      ep = server.reports[0].endpoints[0]
      ep.name.should == 'Testin'
      ep.traces.count.should == 1

      t = ep.traces[0]
      t.spans.count.should == 2
      t.spans[0].should == span(
        event:      event('app.rack.request'),
        started_at: 0,
        duration:   2_000 )
      t.spans[1].should == span(
        parent:     0,
        event:      event('app.foo'),
        started_at: 1_000,
        duration:   1_000 )
    end

    it 'recategorizes unknown events as other' do
      Skylight.trace 'Testin', 'app.rack.request' do |t|
        clock.skip 0.1
        Skylight.instrument category: 'foo' do
          clock.skip 0.1
        end
      end

      clock.unfreeze
      server.wait count: 3

      ep = server.reports[0].endpoints[0]
      t  = ep.traces[0]

      t.spans[1].should == span(
        parent:     0,
        event:      event('other.foo'),
        started_at: 1_000,
        duration:   1_000)
    end

    it 'sets a default category' do
      Skylight.trace 'Testin', 'app.rack.request' do |t|
        clock.skip 0.1
        Skylight.instrument title: 'foo' do
          clock.skip 0.1
        end
      end

      clock.unfreeze
      server.wait count: 3

      ep = server.reports[0].endpoints[0]
      t  = ep.traces[0]

      t.spans[1].should == span(
        parent:     0,
        event:      event('app.block', 'foo'),
        started_at: 1_000,
        duration:   1_000)
    end

    class MyClass
      include Skylight::Helpers

      instrument_method
      def one(arg)
        yield if block_given?
        arg
      end

      def two
        yield if block_given?
      end

      def three
        yield if block_given?
      end

      instrument_method category: "app.winning", title: "Win"
      def custom
        yield if block_given?
      end

      instrument_method :three

      instrument_method
      def self.singleton_method
        yield if block_given?
      end

    end

    it 'tracks instrumented methods using the helper' do
      Skylight.trace 'Testin', 'app.rack.request' do |t|
        inst = MyClass.new

        clock.skip 0.1
        ret = inst.one(:zomg) { clock.skip 0.1; :one }
        ret.should == :zomg

        clock.skip 0.1
        inst.two { clock.skip 0.1 }

        clock.skip 0.1
        ret = inst.three { clock.skip 0.1; :tres }
        ret.should == :tres

        clock.skip 0.1
        inst.custom { clock.skip 0.1 }

        clock.skip 0.1
        MyClass.singleton_method { clock.skip 0.1 }
      end

      clock.unfreeze
      server.wait count: 3

      server.reports[0].endpoints.count.should == 1

      ep = server.reports[0].endpoints[0]
      ep.name.should == 'Testin'
      ep.traces.count.should == 1

      t = ep.traces[0]
      t.spans.count.should == 5

      # Root span
      t.spans[0].should == span(
        event:      event('app.rack.request'),
        started_at: 0,
        duration:   10_000 )

      t.spans[1].should == span(
        parent:     0,
        event:      event('app.method', 'MyClass#one'),
        started_at: 1_000,
        duration:   1_000)

      t.spans[2].should == span(
        parent:     0,
        event:      event('app.method', 'MyClass#three'),
        started_at: 5_000,
        duration:   1_000)

      t.spans[3].should == span(
        parent:     0,
        event:      event('app.winning', 'Win'),
        started_at: 7_000,
        duration:   1_000)

      t.spans[4].should == span(
        parent:     0,
        event:      event('app.method', 'MyClass.singleton_method'),
        started_at: 9_000,
        duration:   1_000)
    end

  end

end
