require 'spec_helper'

module Skylight
  describe GC, :http, :agent do

    before :each do
      clock.freeze
    end

    after :each do
      Skylight.stop!
    end

    context 'when there is no GC and no spans' do

      it 'leaves the GC node out' do
        start!

        expect(gc).to be_enabled
        expect(gc).to receive(:total_time).
          exactly(2).times.and_return(0.0, 0.0)

        Skylight.trace 'Rack', 'app.rack' do |t|
          clock.skip 1
        end

        clock.unfreeze
        server.wait resource: '/report'

        expect(trace.spans.count).to eq(1)
        expect(trace.spans[0].duration).to eq(10_000)
      end

    end

    context 'when there is GC and no spans' do

      it 'adds a GC node' do
        start!

        expect(gc).to be_enabled
        expect(gc).to receive(:total_time).
          exactly(2).times.and_return(0.0, 100_000_000)

        Skylight.trace 'Rack', 'app.rack' do |t|
          clock.skip 1
        end

        clock.unfreeze
        server.wait resource: '/report'

        expect(trace.spans.count).to eq(2)
        expect(span(0).duration).to eq(10_000)

        expect(span(1).event.category).to eq('noise.gc')
        expect(span(1).duration).to eq(1_000)
      end

    end

    context 'when there is GC and a span' do

      it 'subtracts GC from the span and adds it at the end' do
        start!

        expect(gc).to be_enabled
        expect(gc).to receive(:total_time).
          exactly(4).times.and_return(0, 0, 100_000_000, 0)

        Skylight.trace 'Rack', 'app.rack' do |t|
          Skylight.instrument do
            clock.skip 1
          end
        end

        clock.unfreeze
        server.wait resource: '/report'

        expect(trace.spans.count).to eq(3)

        expect(span(0).event.category).to eq('app.rack')
        expect(span(0).duration).to eq(10_000)

        expect(span(1).event.category).to eq('app.block')
        expect(span(1).duration).to eq(9_000)

        expect(span(2).event.category).to eq('noise.gc')
        expect(span(2).duration).to eq(1_000)
      end
    end

    def trace
      server.reports[0].endpoints[0].traces[0]
    end

  end
end
