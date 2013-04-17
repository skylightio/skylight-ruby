require 'spec_helper'

module Skylight
  describe JsonProto do
    subject do
      JsonProto.new(Config.new)
    end

    let(:config) { Config.new }

    it "writes JSON" do
      now = Util.clock.now
      out = ''

      trace1 = Trace.new(config, 'endpoint1')
      Util.clock.stub(:now => now)
      trace1.start("cat1", "title1", "desc1", "annot1")
      Util.clock.stub(:now => now+10)
      trace1.record("cat1.1", "title1.1", "desc1.1", "annot1.1")
      Util.clock.stub(:now => now+20)
      trace1.stop

      trace2 = Trace.new(config, 'endpoint2')
      Util.clock.stub(:now => now+30)
      trace2.start("cat2", "title2", "desc2", "annot2")
      Util.clock.stub(:now => now+45)
      trace2.record("cat2.1", "title2.1", "desc2.1", "annot2.1")
      Util.clock.stub(:now => now+60)
      trace2.stop

      counts = {
        'endpoint1' => 2,
        'endpoint2' => 5
      }

      sample = Util::UniformSample.new(2)
      sample << trace1
      sample << trace2

      subject.write(out, 123456789, counts, sample)

      JSON.parse(out).should == {
        "batch" => {
          "timestamp" => 12345,
          "endpoints" => [
            {
              "name" => 'endpoint1',
              "count" => 2,
              "traces" => [
                {
                  "uuid" => 'TODO',
                  "spans" => [
                    [
                      nil,
                      0,
                      20,
                      'cat1',
                      'title1',
                      'desc1',
                      'annot1'
                    ],
                    [
                      0,
                      10,
                      0,
                      'cat1.1',
                      'title1.1',
                      'desc1.1',
                      'annot1.1'
                    ]
                  ]
                }
              ]
            },
            {
              "name" => 'endpoint2',
              "count" => 5,
              "traces" => [
                {
                  "uuid" => 'TODO',
                  "spans" => [
                    [
                      nil,
                      0,
                      30,
                      'cat2',
                      'title2',
                      'desc2',
                      'annot2'
                    ],
                    [
                      0,
                      15,
                      0,
                      'cat2.1',
                      'title2.1',
                      'desc2.1',
                      'annot2.1'
                    ]
                  ]
                }
              ]
            }
          ]
        }
      }
    end
  end
end
