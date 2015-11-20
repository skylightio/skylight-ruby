require 'spec_helper'

describe 'Excon integration', :excon_probe, :http, :agent, :instrumenter do

  def travel(amount)
    clock.tick += 100_000 * amount # tick value should be nanoseconds (1 billionth of a second)
  end

  def stub_request(opts={}, &block)
    path = "/#{opts[:path]}"
    method = opts[:method] || :get
    delay  = opts[:delay] || 1 # agent talks units of 100 microseconds (10,000ths of a second)

    server.mock path, method do
      travel(delay)
      block.call() if block
      [200, '']
    end
  end

  it "logs successful requests" do
    stub_request
    Excon.get(server_uri)

    expected = {
      cat: "api.http.get",
      title: "GET localhost",
      duration: 1
    }
    expect(current_trace.mock_spans[1]).to include(expected)
  end

  context "errors" do
    before :each do
      # Using mocks since its hard to trigger error cases otherwise
      Excon.defaults[:mock] = true
    end

    after :each do
      Excon.defaults[:mock] = false
      Excon.stubs.clear
    end

    it "logs errored requests" do
      Excon.stub({}, lambda{|request_params|
        travel(2)
        raise "bad response"
        { :body => 'body', :status => 200 }
      })

      Excon.get("http://example.com") rescue nil

      expected = {
        cat: "api.http.get",
        title: "GET example.com",
        duration: 2
      }
      expect(current_trace.mock_spans[1]).to include(expected)
    end

  end

  context "descriptions" do

    %w(connect delete get head options patch post put trace).each do |verb|
      it "describes #{verb}" do
        stub_request(method: verb)

        Excon.send(verb, server_uri)

        expect(current_trace.mock_spans[1]).to include(cat: "api.http.#{verb}", title: "#{verb.upcase} localhost")
      end
    end

    it "describes https"

    # These should not be included in the description
    it "describes default ports"

    it "describes paths" do
      stub_request

      Excon.get("#{server_uri}/path/to/file")

      expect(current_trace.mock_spans[1]).to include(cat: "api.http.get", title: "GET localhost")
    end

    it "describes queries" do
      stub_request

      Excon.get("#{server_uri}/path/to/file?foo=bar&baz=qux")

      expect(current_trace.mock_spans[1]).to include(cat: "api.http.get", title: "GET localhost")
    end
  end

end
