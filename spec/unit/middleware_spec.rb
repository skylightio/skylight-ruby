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
    allow(e).to receive(:hello)
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
    expect(Skylight).to receive('trace').and_call_original
    expect(env).to receive(:hello)

    _, _, body = app.call(env)
    body.close

    clock.unfreeze
    server.wait resource: "/report"

    report = server.reports[0]
    expect(report).to_not be_nil
    expect(report.endpoints.count).to eq(1)

    ep = server.reports[0].endpoints[0]
    expect(ep.name).to eq('Rack')
    expect(ep.traces.count).to eq(1)

    t = ep.traces[0]
    expect(t.spans.count).to eq(2)


    expect(t.spans[0]).to eq(span(
      event: event('app.rack.request'),
      started_at: 0,
      duration: 3_000 ))

    expect(t.spans[1]).to eq(span(
      parent: 0,
      event: event('app.block', 'hello'),
      started_at: 1_000,
      duration:   2_000))
  end

  it 'skips HEAD' do
    expect(Skylight).to_not receive('trace')

    env['REQUEST_METHOD'] = 'HEAD'

    app.call(env)
  end

end
