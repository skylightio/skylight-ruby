require "spec_helper"

describe "Faraday integration", :faraday_probe, :http, :agent, :instrumenter do
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

  let :client do
    Faraday.new(url: server_uri)
  end

  it "instruments get requests" do
    response = client.get(uri)
    expect(response).to be_a(Faraday::Response)
    expect(response.status).to eq(200)

    expect(current_trace.mock_spans).to include(
      a_hash_including(cat: "api.http.get", title: "Faraday", desc: "GET 127.0.0.1")
    )
  end

  it "instruments post requests" do
    response = client.post(uri, body: "Hi there!")
    expect(response).to be_a(Faraday::Response)
    expect(response.status).to eq(200)

    expect(current_trace.mock_spans).to include(
      a_hash_including(cat: "api.http.post", title: "Faraday", desc: "POST 127.0.0.1")
    )
  end

  it "instruments multipart post requests" do
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
    expect(response).to be_a(Faraday::Response)
    expect(response.status).to eq(200)

    expect(current_trace.mock_spans).to include(
      a_hash_including(cat: "api.http.post", title: "Faraday", desc: "POST 127.0.0.1")
    )
  end

  it "instruments head requests" do
    response = client.head(uri)
    expect(response).to be_a(Faraday::Response)
    expect(response.status).to eq(200)

    expect(current_trace.mock_spans).to include(
      a_hash_including(cat: "api.http.head", title: "Faraday", desc: "HEAD 127.0.0.1")
    )
  end

  it "instruments Faraday.methodname static methods" do
    response = Faraday.get(uri)
    expect(response).to be_a(Faraday::Response)
    expect(response.status).to eq(200)

    expect(current_trace.mock_spans).to include(
      a_hash_including(cat: "api.http.get", title: "Faraday", desc: "GET 127.0.0.1")
    )
  end
end
