require "spec_helper"

describe "HTTPClient integration", :httpclient_probe, :http, :agent do
  before(:each) do
    server.mock "/test.html" do
      ret = "Testing"
      [200, { "content-type" => "text/plain", "content-length" => ret.bytesize.to_s }, [ret]]
    end
  end

  def server_uri
    "http://127.0.0.1:#{port}"
  end

  let :uri do
    URI.parse("#{server_uri}/test.html")
  end

  let(:probe) { Skylight::Probes::HTTPClient::Probe }

  it "instruments get requests" do
    expected = { category: "api.http.get", title: "GET 127.0.0.1", internal: true }

    expect(Skylight).to receive(:instrument).with(expected).and_call_original

    client = HTTPClient.new

    response = client.get(uri)
    expect(response).to be_a(HTTP::Message)
    expect(response).to be_ok
  end

  it "instruments post requests" do
    expected = { category: "api.http.post", title: "POST 127.0.0.1", internal: true }

    expect(Skylight).to receive(:instrument).with(expected).and_call_original

    client = HTTPClient.new

    response = client.post(uri, body: "Hi there!")
    expect(response).to be_a(HTTP::Message)
    expect(response).to be_ok
  end

  it "instruments multipart post requests" do
    expected = { category: "api.http.post", title: "POST 127.0.0.1", internal: true }

    expect(Skylight).to receive(:instrument).with(expected).and_call_original

    client = HTTPClient.new

    response =
      client.post(
        uri,
        header: {
          "Content-Type" => "multipart/form-data"
        },
        body: [
          {
            "Content-Type" => "text/plain; charset=UTF-8",
            "Content-Disposition" => "form-data; name=\"name\"",
            :content => "Barry"
          },
          {
            "Content-Type" => "text/plain; charset=UTF-8",
            "Content-Disposition" => "form-data; name=\"department\"",
            :content => "Accounting"
          }
        ]
      )
    expect(response).to be_a(HTTP::Message)
    expect(response).to be_ok
  end

  it "instruments head requests" do
    expected = { category: "api.http.head", title: "HEAD 127.0.0.1", internal: true }

    expect(Skylight).to receive(:instrument).with(expected).and_call_original

    client = HTTPClient.new

    response = client.head(uri)
    expect(response).to be_a(HTTP::Message)
    expect(response).to be_ok
  end

  it "instruments custom method requests" do
    expected = { category: "api.http.custom", title: "CUSTOM 127.0.0.1", internal: true }

    expect(Skylight).to receive(:instrument).with(expected).and_call_original

    client = HTTPClient.new

    response = client.request("CUSTOM", uri)
    expect(response).to be_a(HTTP::Message)
    # Later versions of puma (>= 6) hardcode this to return a 501 response.
    # expect(response).to be_ok
  end

  it "instruments HTTPClient.methodname static methods" do
    expected = { category: "api.http.get", title: "GET 127.0.0.1", internal: true }

    expect(Skylight).to receive(:instrument).with(expected).and_call_original

    response = HTTPClient.get(uri)
    expect(response).to be_a(HTTP::Message)
    expect(response).to be_ok
  end

  it "does not instrument when disabled" do
    expect(Skylight).not_to receive(:instrument)

    Skylight::Probes::HTTPClient::Probe.disable do
      client = HTTPClient.new
      response = client.get(uri)
      expect(response).to be_a(HTTP::Message)
      expect(response).to be_ok
      expect(probe).to be_disabled
    end

    expect(probe).not_to be_disabled
  end

  it "handles nested `disable` blocks" do
    expect(Skylight).not_to receive(:instrument)

    Skylight::Probes::HTTPClient::Probe.disable do
      Skylight::Probes::HTTPClient::Probe.disable { expect(probe).to be_disabled }

      expect(probe).to be_disabled

      client = HTTPClient.new
      response = client.get(uri)
      expect(response).to be_a(HTTP::Message)
      expect(response).to be_ok
    end

    expect(probe).not_to be_disabled
  end
end
