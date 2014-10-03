require 'spec_helper'

describe "Skylight::Middleware", :http, :agent do

  before :each do
    start!
    clock.freeze
  end

  after :each do
    Skylight.stop!
  end

  let :env do
    e = {}
    e.stub(:hello)
    e
  end

  let :app do
    Skylight::Middleware.new(lambda do |env|
      clock.skip 0.1

      Skylight.instrument 'hello' do
        clock.skip 0.2
      end

      env.hello

      [ 200, {}, [] ]
    end)
  end

  it 'tracks traces' do
    Skylight.should_receive('trace').and_call_original
    env.should_receive(:hello)

    _, _, body = app.call(env)
    body.close

    clock.unfreeze
    server.wait count: 1, resource: "/report"

    report = server.reports[0]
    report.should_not be_nil
    report.endpoints.count.should == 1

    ep = server.reports[0].endpoints[0]
    ep.name.should == 'Rack'
    ep.traces.count.should == 1

    t = ep.traces[0]
    t.spans.count.should == 2


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

  it 'skips HEAD' do
    Skylight.should_not_receive('trace')

    env['REQUEST_METHOD'] = 'HEAD'

    app.call(env)
  end

end
