require 'spec_helper'

describe "Skylight::Instrumenter", :http, :agent do

  let :hello do
    double('hello')
  end

  context 'when the instrumenter is not running' do

    it 'does not break code' do
      expect(hello).to receive(:hello)

      Skylight.trace 'Zomg', 'app.rack.request' do |t|
        expect(t).to be_nil

        ret = Skylight.instrument category: 'foo.bar' do |s|
          expect(s).to be_nil
          hello.hello
          1
        end

        expect(ret).to eq(1)
      end

      expect(Skylight::Instrumenter.instance).to be_nil
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
      expect(hello).to receive(:hello)

      Skylight.trace 'Testin', 'app.rack.request' do |t|
        clock.skip 0.1
        ret = Skylight.instrument category: 'app.foo' do
          clock.skip 0.1
          hello.hello
          3
        end

        expect(ret).to eq(3)
      end

      clock.unfreeze
      server.wait resource: '/report'

      expect(server.reports[0].endpoints.count).to eq(1)

      ep = server.reports[0].endpoints[0]
      expect(ep.name).to eq('Testin')
      expect(ep.traces.count).to eq(1)

      t = ep.traces[0]
      expect(t.spans.count).to eq(2)
      expect(t.spans[0]).to eq(span(
        event:      event('app.rack.request'),
        started_at: 0,
        duration:   2_000 ))
      expect(t.spans[1]).to eq(span(
        parent:     0,
        event:      event('app.foo'),
        started_at: 1_000,
        duration:   1_000 ))
    end

    it 'recategorizes unknown events as other' do
      Skylight.trace 'Testin', 'app.rack.request' do |t|
        clock.skip 0.1
        Skylight.instrument category: 'foo' do
          clock.skip 0.1
        end
      end

      clock.unfreeze
      server.wait resource: '/report'

      ep = server.reports[0].endpoints[0]
      t  = ep.traces[0]

      expect(t.spans[1]).to eq(span(
        parent:     0,
        event:      event('other.foo'),
        started_at: 1_000,
        duration:   1_000))
    end

    it 'sets a default category' do
      Skylight.trace 'Testin', 'app.rack.request' do |t|
        clock.skip 0.1
        Skylight.instrument title: 'foo' do
          clock.skip 0.1
        end
      end

      clock.unfreeze
      server.wait resource: '/report'

      ep = server.reports[0].endpoints[0]
      t  = ep.traces[0]

      expect(t.spans[1]).to eq(span(
        parent:     0,
        event:      event('app.block', 'foo'),
        started_at: 1_000,
        duration:   1_000))
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

      def self.singleton_method_without_options
        yield if block_given?
      end
      instrument_class_method :singleton_method_without_options

      def self.singleton_method_with_options
        yield if block_given?
      end
      instrument_class_method :singleton_method_with_options,
        category: 'app.singleton',
        title: 'Singleton Method'

      attr_accessor :myvar
      instrument_method :myvar=
    end

    it 'tracks instrumented methods using the helper' do
      Skylight.trace 'Testin', 'app.rack.request' do |t|
        inst = MyClass.new

        clock.skip 0.1
        ret = inst.one(:zomg) { clock.skip 0.1; :one }
        expect(ret).to eq(:zomg)

        clock.skip 0.1
        inst.two { clock.skip 0.1 }

        clock.skip 0.1
        ret = inst.three { clock.skip 0.1; :tres }
        expect(ret).to eq(:tres)

        clock.skip 0.1
        inst.custom { clock.skip 0.1 }

        clock.skip 0.1
        MyClass.singleton_method { clock.skip 0.1 }

        clock.skip 0.1
        MyClass.singleton_method_without_options { clock.skip 0.1 }

        clock.skip 0.1
        MyClass.singleton_method_with_options { clock.skip 0.1 }

        clock.skip 0.1
        ret = (inst.myvar = :foo)
        expect(ret).to eq(:foo)
        expect(inst.myvar).to eq(:foo)
      end

      clock.unfreeze
      server.wait resource: '/report'

      expect(server.reports[0].endpoints.count).to eq(1)

      ep = server.reports[0].endpoints[0]
      expect(ep.name).to eq('Testin')
      expect(ep.traces.count).to eq(1)

      t = ep.traces[0]
      expect(t.spans.count).to eq(8)

      # Root span
      expect(t.spans[0]).to eq(span(
        event:      event('app.rack.request'),
        started_at: 0,
        duration:   15_000 ))

      expect(t.spans[1]).to eq(span(
        parent:     0,
        event:      event('app.method', 'MyClass#one'),
        started_at: 1_000,
        duration:   1_000))

      expect(t.spans[2]).to eq(span(
        parent:     0,
        event:      event('app.method', 'MyClass#three'),
        started_at: 5_000,
        duration:   1_000))

      expect(t.spans[3]).to eq(span(
        parent:     0,
        event:      event('app.winning', 'Win'),
        started_at: 7_000,
        duration:   1_000))

      expect(t.spans[4]).to eq(span(
        parent:     0,
        event:      event('app.method', 'MyClass.singleton_method'),
        started_at: 9_000,
        duration:   1_000))

      expect(t.spans[5]).to eq(span(
        parent:     0,
        event:      event('app.method', 'MyClass.singleton_method_without_options'),
        started_at: 11_000,
        duration:   1_000))

      expect(t.spans[6]).to eq(span(
        parent:     0,
        event:      event('app.singleton', 'Singleton Method'),
        started_at: 13_000,
        duration:   1_000))

      expect(t.spans[7]).to eq(span(
        parent:     0,
        event:      event('app.method', 'MyClass#myvar='),
        started_at: 15_000,
        duration:   0))
    end

  end

end
