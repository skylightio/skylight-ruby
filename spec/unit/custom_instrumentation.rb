require 'spec_helper'

describe Skylight::Instrumenter do

  let :instrumenter do
    Skylight::Instrumenter.new config
  end

  context 'when the instrumenter is not running' do

    it 'does not break code' do
      m = double('hello')
      m.should_receive(:hello)

      instrumenter.trace 'Zomg' do |t|
        t.should be_nil

        instrumenter.instrument 'foo.bar' do |s|
          s.should be_nil
          m.hello
        end
      end

      instrumenter.should_not_receive(:process)
    end

  end

  context 'when the instrumenter is running' do

    before :each do
      instrumenter.start!
      clock.freeze
    end

    after :each do
      instrumenter.shutdown
    end

    it 'tracks custom instrumentation metrics' do
      instrumenter.trace 'Testin' do |t|
        t.root 'app.rack' do
          clock.skip 0.1
          instrumenter.
        end
      end

      clock.unfreeze
      server.wait

      server.reports[0].should have(1).endpoints

      ep = server.reports[0].endpoints[0]
      ep.name.should == 'Testin'
      ep.should have(1).traces

      t = ep.traces[0]
      t.should have(1).spans
      t.uuid.should == 'TODO'
      t.spans[0].should == span(
        event:      event('app.rack'),
        started_at: 0,
        duration:   10_000 )
    end

  end

end
