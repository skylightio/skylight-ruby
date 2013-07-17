require 'spec_helper'

describe Skylight::Instrumenter, :http do

  shared_examples 'an instrumenter' do

    before :each do
      Skylight.start! config
      clock.freeze
    end

    after :each do
      Skylight.stop!
    end

    it 'records the trace' do
      stub_session_request

      Skylight.trace 'Testin', 'app.rack' do |t|
        clock.skip 1
      end

      clock.unfreeze
      server.wait(timeout: 2, count: 2)

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

  context 'embedded' do

    let(:agent_strategy) { 'embedded' }

    it_behaves_like 'an instrumenter'

  end

  context 'standalone' do

    let(:log_path) { tmp('skylight.log') }
    let(:agent_strategy) { 'standalone' }

    it_behaves_like 'an instrumenter'

  end unless defined?(JRUBY_VERSION)

end
