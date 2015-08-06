require 'spec_helper'

describe 'Net::HTTP integration', :net_http_probe, :http, :agent do

  class CustomType < Net::HTTPRequest
    METHOD = "CUSTOM"
    REQUEST_HAS_BODY = false
    RESPONSE_HAS_BODY = false
  end

  before(:each) do
    server.mock "/test.html" do
      ret = 'Testing'
      [ 200, { 'content-type' => 'text/plain', 'content-length' => ret.bytesize.to_s }, [ret] ]
    end
  end

  def server_uri
    "http://localhost:#{port}"
  end

  let :uri do
    URI.parse("#{server_uri}/test.html")
  end

  it "instruments basic requests" do
    expected = {
      category: "api.http.get",
      title: "GET localhost"
    }
    Skylight.should_receive(:instrument).with(expected).and_call_original

    response = Net::HTTP.get_response(uri)

    response.should be_a(Net::HTTPOK)
  end

  it "instruments verbose requests" do
     expected = {
      category: "api.http.get",
      title: "GET localhost"
    }
    Skylight.should_receive(:instrument).with(expected).and_call_original

    http = Net::HTTP.new(uri.host, uri.port)
    response = http.request(Net::HTTP::Get.new(uri.request_uri))

    response.should be_a(Net::HTTPOK)
  end

  it "instruments basic auth requests" do
    expected = {
      category: "api.http.get",
      title: "GET localhost"
    }
    Skylight.should_receive(:instrument).with(expected).and_call_original

    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Get.new(uri.request_uri)
    request.basic_auth("username", "password")
    response = http.request(request)

    response.should be_a(Net::HTTPOK)
  end

  it "instruments post_form requests" do
    expected = {
      category: "api.http.post",
      title: "POST localhost"
    }

    Skylight.should_receive(:instrument).with(expected).and_call_original

    response = Net::HTTP.post_form(uri, {"q" => "My query", "per_page" => "50"})

    response.should be_a(Net::HTTPOK)
  end

  it "instruments post requests" do
     expected = {
      category: "api.http.post",
      title: "POST localhost"
    }

    Skylight.should_receive(:instrument).with(expected).and_call_original

    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri.request_uri)
    request.set_form_data({"q" => "My query", "per_page" => "50"})
    response = http.request(request)

    response.should be_a(Net::HTTPOK)
  end

  it "instruments https requests" do
    skip "needs test server tweaks"

    # Skylight.should_receive(:instrument).with(category: "api.http.get", title: "GET localhost",
    #                                             description: "GET #{server_uri}/test.html").and_call_original

    # uri = URI.parse("https://localhost/test.html")
    # http = Net::HTTP.new(uri.host, port)
    # http.use_ssl = true
    # http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    # request = Net::HTTP::Get.new(uri.request_uri)

    # response = http.request(request)

    # response.should be_a(Net::HTTPOK)
  end

  it "instruments PUT requests" do
     expected = {
      category: "api.http.put",
      title: "PUT localhost"
    }

    Skylight.should_receive(:instrument).with(expected).and_call_original

    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Put.new(uri.request_uri)
    request.set_form_data({"users[login]" => "changed"})
    response = http.request(request)

    response.should be_a(Net::HTTPOK)
  end

  it "instruments DELETE requests" do
    expected = {
      category: "api.http.delete",
      title: "DELETE localhost"
    }

    Skylight.should_receive(:instrument).with(expected).and_call_original

    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Delete.new(uri.request_uri)
    request.set_form_data({"users[login]" => "changed"})
    response = http.request(request)

    response.should be_a(Net::HTTPOK)
  end

  it "instruments timedout requests" do
    server.mock "/slow.html" do
      sleep 2
      ret = 'Slow'
      [ 200, { 'content-type' => 'text/plain', 'content-length' => ret.bytesize.to_s }, [ret] ]
    end

    uri = URI.parse("#{server_uri}/slow.html")

    expected = {
      category: "api.http.get",
      title: "GET localhost"
    }

    Skylight.should_receive(:instrument).with(expected).and_call_original

    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 0.1 # in seconds
    http.read_timeout = 0.1 # in seconds

    lambda {
      http.request(Net::HTTP::Get.new(uri.request_uri))
    }.should raise_error
  end

  it "instruments non-URI requests" do
    expected = {
      category: "api.http.get",
      title: "GET localhost"
    }

    Skylight.should_receive(:instrument).with(expected).and_call_original

    http = Net::HTTP.new("localhost", port)
    response = http.request(Net::HTTP::Get.new("/test.html"))

    response.should be_a(Net::HTTPOK)
  end

  it "instruments custom verbs" do
    expected = {
      category: "api.http.custom",
      title: "CUSTOM localhost"
    }

    Skylight.should_receive(:instrument).with(expected).and_call_original

    http = Net::HTTP.new("localhost", port)
    response = http.request(CustomType.new("/test.html"))

    response.should be_a(Net::HTTPOK)
  end

  it "instruments basic auth" do
    expected = {
      category: "api.http.get",
      title: "GET localhost"
    }

    Skylight.should_receive(:instrument).with(expected).and_call_original

    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Get.new(uri.request_uri)
    request.basic_auth("username", "password")
    response = http.request(request)

    response.should be_a(Net::HTTPOK)
  end

  it "instruments multiple requests with the same socket" do
    expected = {
      category: "api.http.get",
      title: "GET localhost"
    }

    Skylight.should_receive(:instrument).with(expected).twice.and_call_original


    http = Net::HTTP.new(uri.host, uri.port)
    response1 = http.request(Net::HTTP::Get.new(uri.request_uri))
    response2 = http.request(Net::HTTP::Get.new(uri.request_uri))

    response1.should be_a(Net::HTTPOK)
    response2.should be_a(Net::HTTPOK)
  end

end
