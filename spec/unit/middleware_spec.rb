require 'spec_helper'

describe Skylight::Middleware, :http do

  before :each do
    start!
    clock.freeze
  end

  after :each do
    Skylight.stop!
  end

  let :hello do
    double('hello')
  end

  it 'tracks traces' do
    hello.should_receive(:hello)

    app = Skylight::Middleware.new(lambda do |env|
      clock.skip 0.1

      Skylight.instrument 'hello' do
        clock.skip 0.2
      end

      env.hello

      [ 200, {}, [] ]
    end)

    _, _, body = app.call(hello)
    body.close

    clock.unfreeze
    server.wait count: 2

    server.reports[0].should have(1).endpoints

    ep = server.reports[0].endpoints[0]
    ep.name.should == 'Rack'
    ep.should have(1).traces

    t = ep.traces[0]
    t.should have(2).spans


    t.spans[0].should == span(
      event: event('app.rack.request'),
      started_at: 0,
      duration: 3_000 )

    t.spans[1].should == span(
      parent: 0,
      event: event('app.block', 'hello'),
      started_at: 1_000,
      duration:   2_000)
  end

end
