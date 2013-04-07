require 'spec_helper'

module Skylight
  describe Trace do

    let :trace do
      Trace.new
    end

    def create_span(opts = {})
      opts = {
        :parent      => "parent",
        :started_at  => "started_at",
        :category    => "category",
        :title       => "title",
        :description => "description",
        :annotations => "annotations",
        :ended_at    => "ended_at"
      }.merge(opts)

      Trace::Span.new(
        opts[:parent],
        opts[:started_at],
        opts[:category],
        opts[:title],
        opts[:description],
        opts[:annotations],
        opts[:ended_at]
      )
    end

    let(:span){ create_span }

    it "can get current" do
      begin
        Thread.current[Trace::KEY] = trace
        Trace.current.should == trace
      ensure
        Thread.current[Trace::KEY] = nil
      end
    end

    describe Trace::Span do
      it "has standard properties" do
        span.parent.should == "parent"
        span.started_at.should == "started_at"
        span.ended_at.should == "ended_at"
        span.category.should == "category"
        span.description.should == "description"
        span.annotations.should == "annotations"
      end

      it "has key" do
        span.key.should == ["category", "description"]
      end
    end

    it "defaults the endpoint" do
      trace.endpoint.should == "Unknown"
    end

    describe "from" do
      it "returns the first started_at" do
        trace.spans << create_span(:started_at => "one")
        trace.spans << create_span(:started_at => "two")
        trace.from.should == "one"
      end

      it "returns nil if no spans" do
        trace.from.should be_nil
      end
    end

    describe "to" do
      it "returns the last ended_at" do
        trace.spans << create_span(:ended_at => "one")
        trace.spans << create_span(:ended_at => "two")
        trace.to.should == "two"
      end

      it "returns nil if no spans" do
        trace.to.should be_nil
      end
    end

    describe "start" do
      it "creates spans" do
        now = Util.clock.now
        Util.clock.stub(:now).and_return(now)
        trace.start("cat1", "title1", "desc1", "annot1")

        Util.clock.stub(:now).and_return(now+1)
        trace.start("cat2", "title2", "desc2", "annot2")

        Util.clock.stub(:now).and_return(now+2)
        trace.start("cat3", "title3","desc3", "annot3")

        trace.spans[0].parent.should == nil
        trace.spans[0].started_at.should == now
        trace.spans[0].ended_at.should == nil
        trace.spans[0].category.should == "cat1"
        trace.spans[0].title.should == "title1"
        trace.spans[0].description.should == "desc1"
        trace.spans[0].annotations.should == "annot1"

        trace.spans[1].parent.should == 0
        trace.spans[1].started_at.should == now + 1
        trace.spans[1].ended_at.should == nil
        trace.spans[1].category.should == "cat2"
        trace.spans[1].title.should == "title2"
        trace.spans[1].description.should == "desc2"
        trace.spans[1].annotations.should == "annot2"

        trace.spans[2].parent.should == 1
        trace.spans[2].started_at.should == now + 2
        trace.spans[2].ended_at.should == nil
        trace.spans[2].category.should == "cat3"
        trace.spans[2].title.should == "title3"
        trace.spans[2].description.should == "desc3"
        trace.spans[2].annotations.should == "annot3"
      end
    end

    describe "stop" do
      it "sets ended_at" do
        now = Util.clock.now
        Util.clock.stub(:now).and_return(now)
        trace.start("cat", "title", "desc", "annot")

        Util.clock.stub(:now).and_return(now+1)
        trace.stop

        trace.spans[0].started_at.should == now
        trace.spans[0].ended_at.should == now + 1
      end

      it "adjusts parent" do
        trace.start("cat1", "title1", "desc1", "annot1")
        trace.start("cat2", "title2", "desc2", "annot2")
        trace.start("cat3", "title3", "desc3", "annot3")
        trace.stop
        trace.stop
        trace.start("cat4", "title4", "desc4", "annot4")
        trace.stop
        trace.stop
        trace.start("cat5", "title5", "desc5", "annot5")

        trace.spans[0].parent.should == nil
        trace.spans[1].parent.should == 0
        trace.spans[2].parent.should == 1
        trace.spans[3].parent.should == 0
        trace.spans[4].parent.should == nil
      end

      it "sets ended_at on last unclosed span" do
        now = Util.clock.now

        Util.clock.stub(:now => now)
        trace.start("cat1", nil, nil, nil)
        Util.clock.stub(:now => now+10)
        trace.start("cat2", nil, nil, nil)
        Util.clock.stub(:now => now+20)
        trace.start("cat3", nil, nil, nil)
        Util.clock.stub(:now => now+30)
        trace.stop
        Util.clock.stub(:now => now+40)
        trace.stop
        Util.clock.stub(:now => now+50)
        trace.stop

        trace.spans[0].started_at.should == now
        trace.spans[0].ended_at.should == now+50

        trace.spans[1].started_at.should == now+10
        trace.spans[1].ended_at.should == now+40

        trace.spans[2].started_at.should == now+20
        trace.spans[2].ended_at.should == now+30
      end

      it "raises if no spans" do
        trace.start("cat1", "title1", "desc1", "annot1")
        trace.stop
        lambda{ trace.stop }.should raise_error("trace unbalanced")
      end

      it "raise if all spans are closed" do
        trace.record("cat", "title", "desc", "annot")
        lambda { trace.stop }.should raise_error("trace unbalanced")
      end

    end
  end
end
