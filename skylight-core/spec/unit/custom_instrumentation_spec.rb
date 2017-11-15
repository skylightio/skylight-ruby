require 'spec_helper'

module Skylight::Core
  describe Instrumenter do

    let :hello do
      double('hello')
    end

    context 'when the instrumenter is not running' do

      it 'does not break code' do
        expect(hello).to receive(:hello)

        Skylight::Test.trace 'Zomg', 'app.rack.request' do |t|
          expect(t).to be_nil

          ret = Skylight::Test.instrument category: 'foo.bar' do |s|
            expect(s).to be_nil
            hello.hello
            1
          end

          expect(ret).to eq(1)
        end

        expect(Skylight::Test.instrumenter).to be_nil
      end

    end

  end
end
