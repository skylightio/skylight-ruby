require 'spec_helper'

describe 'Excon integration', :excon_probe, :http, :agent do

  class TestSpan
    def self.spans
      @@spans ||= []
    end

    attr_reader :opts

    def initialize(opts)
      TestSpan.spans << self
      @start = Time.now
      @opts = opts
    end

    def done
      @end = Time.now
    end

    def duration
      return nil unless @start && @end
      # Sometimes we get very slight millisecond offsets
      # Consider it good enough if it's off by less than .05 ms
      @end - @start
    end
  end

  let :now do
    Time.now
  end

  before :each do
    Timecop.freeze(now)

    # This is a bit risky to stub :/
    Skylight.stub(:instrument) {|opts| TestSpan.new(opts) }
  end

  after :each do
    Timecop.return
    TestSpan.spans.clear
  end

  def stub_request(opts={}, &block)
    path = "/#{opts[:path]}"
    method = opts[:method] || :get
    delay  = opts[:delay] || 1

    server.mock path, method do
      Timecop.freeze(now + delay)
      block.call() if block
      [200, '']
    end
  end

  it "logs successful requests" do
    stub_request

    Excon.get(server_uri)

    TestSpan.spans.length.should == 1

    span = TestSpan.spans[0]
    span.duration.should == 1
    span.opts.should == {
      category:    "api.http.get",
      title:       "GET localhost"
    }
  end

  context "errors" do
    before :each do
      # Using mocks since its hard to trigger error cases otherwise
      Excon.defaults[:mock] = true
    end

    it "logs errored requests" do
      Excon.stub({}, lambda{|request_params|
        Timecop.freeze(now + 2)
        raise "bad response"
        { :body => 'body', :status => 200 }
      })

      Excon.get("http://example.com") rescue nil

      span = TestSpan.spans[0]
      span.duration.should == 2
      span.opts.should == {
        category:    "api.http.get",
        title:       "GET example.com"
      }
    end

    after :each do
      Excon.defaults[:mock] = false
      Excon.stubs.clear
    end
  end

  context "descriptions" do

    %w(connect delete get head options patch post put trace).each do |verb|
      it "describes #{verb}" do
        stub_request(method: verb)

        Excon.send(verb, server_uri)
        TestSpan.spans.last.opts.should == {
          category:    "api.http.#{verb}",
          title:       "#{verb.upcase} localhost"
        }
      end
    end

    it "describes https"

    # These should not be included in the description
    it "describes default ports"

    it "describes paths" do
      stub_request

      Excon.get("#{server_uri}/path/to/file")
      TestSpan.spans.last.opts.should == {
        category:    "api.http.get",
        title:       "GET localhost"
      }
    end

    it "describes queries" do
      stub_request

      Excon.get("#{server_uri}/path/to/file?foo=bar&baz=qux")
      TestSpan.spans.last.opts.should == {
        category:    "api.http.get",
        title:       "GET localhost"
      }
    end
  end

end
