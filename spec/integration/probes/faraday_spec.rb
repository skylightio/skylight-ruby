require "spec_helper"

describe "Faraday integration", :faraday_probe, :http, :faraday, :agent do
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

  it "instruments get requests" do
    expected = {
      category: "api.http.get",
      title: "GET 127.0.0.1"
    }

    expect(Skylight).to receive(:instrument).with(expected).and_call_original

    client = Faraday.new(url: server_uri)

    response = client.get("/test.html")
    expect(response).to be_a(Faraday::Response)
    expect(response.status).to eq(200)
  end

  it "instruments post requests" do
    expected = {
      category: "api.http.post",
      title: "POST 127.0.0.1"
    }

    expect(Skylight).to receive(:instrument).with(expected).and_call_original

    client = Faraday.new(url: server_uri)

    response = client.post(uri, body: "Hi there!")
    expect(response).to be_a(Faraday::Response)
    expect(response.status).to eq(200)
  end

  it "instruments multipart post requests" do
    expected = {
      category: "api.http.post",
      title: "POST 127.0.0.1"
    }

    expect(Skylight).to receive(:instrument).with(expected).and_call_original

    client = Faraday.new(url: server_uri)

    response = client.post(uri, header: { "Content-Type" => "multipart/form-data" }, body: [{
      "Content-Type" => "text/plain; charset=UTF-8",
      "Content-Disposition" => 'form-data; name="name"',
      :content => "Barry"
    }, {
      "Content-Type" => "text/plain; charset=UTF-8",
      "Content-Disposition" => 'form-data; name="department"',
      :content => "Accounting"
    }])
    expect(response).to be_a(Faraday::Response)
    expect(response.status).to eq(200)
  end

  it "instruments head requests" do
    expected = {
      category: "api.http.head",
      title: "HEAD 127.0.0.1"
    }

    expect(Skylight).to receive(:instrument).with(expected).and_call_original

    client = Faraday.new(url: server_uri)

    response = client.head(uri)
    expect(response).to be_a(Faraday::Response)
    expect(response.status).to eq(200)
  end

  it "instruments Faraday.methodname static methods" do
    expected = {
      category: "api.http.get",
      title: "GET 127.0.0.1"
    }

    expect(Skylight).to receive(:instrument).with(expected).and_call_original

    response = Faraday.get(uri)
    expect(response).to be_a(Faraday::Response)
    expect(response.status).to eq(200)
  end
end
