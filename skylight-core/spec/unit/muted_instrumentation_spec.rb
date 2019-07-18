# frozen_string_literal: true

require "spec_helper"

module Skylight::Core
  describe Instrumenter do
    let :hello do
      double("hello")
    end

    context "when the instrumenter is not running" do
      it "does not break code" do
        expect(hello).to receive(:hello)

        TestNamespace.trace "Zomg", "app.rack.request" do |t|
          expect(t).to be_nil

          expect(TestNamespace).not_to be_muted

          ret = TestNamespace.mute do |s|
            # instrumenter is not running
            expect(TestNamespace).not_to be_muted
            expect(s).to be_nil
            hello.hello
            1
          end

          expect(ret).to eq(1)
        end

        expect(TestNamespace.instrumenter).to be_nil
      end
    end
  end
end
