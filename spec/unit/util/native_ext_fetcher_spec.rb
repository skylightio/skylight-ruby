require 'spec_helper'
require 'skylight/util/native_ext_fetcher'

module Skylight::Util
  describe NativeExtFetcher do

    around :each do |example|
      WebMock.enable!
      Dir.mktmpdir do |dir|
        @target = dir
        example.run
      end
      WebMock.disable!
    end

    let :archive do
      File.read(File.expand_path("../../../support/win.tar.gz", __FILE__))
    end

    let :checksum do
      Digest::SHA2.hexdigest(archive)
    end

    context 'fetching successfully' do

      it 'fetches the native extension' do
        stub_ext_request

        ret = fetch version: "1.0.0", target: @target, arch: "linux-x86_64", checksum: checksum
        expect(ret).to eq(true)
        expect_valid_output
      end

      it 'works with a proxy' do
        begin
          original_proxy = ENV['HTTP_PROXY']
          ENV['HTTP_PROXY'] = "foo:bar@127.0.0.1:123"

          expect(Net::HTTP).to receive(:start).
            with("s3.amazonaws.com", 443, "127.0.0.1", 123, "foo", "bar", use_ssl: true).
            and_return([ :success, checksum ])

          ret = fetch version: "1.0.0", target: @target, arch: "linux-x86_64", checksum: checksum
          expect(ret).to eq(true)
        ensure
          ENV['HTTP_PROXY'] = original_proxy
        end
      end

      it 'follows redirects' do
        stub_request(:get, "https://s3.amazonaws.com/skylight-agent-packages/skylight-native/1.0.0/skylight_linux-x86_64.tar.gz").
          to_return(:status => 301, headers: { 'Location' => "https://example.org/zomg/bar.gz" })

        stub_ext_request("https://example.org/zomg/bar.gz")

        ret = fetch version: "1.0.0", target: @target, arch: "linux-x86_64", checksum: checksum
        expect(ret).to eq(true)
        expect_valid_output
      end

      it 'retries on failure' do
        expect_any_instance_of(NativeExtFetcher).to receive(:http_get) { raise "nope" }.
          with("s3.amazonaws.com", 443, true, "/skylight-agent-packages/skylight-native/1.0.0/skylight_linux-x86_64.tar.gz", an_instance_of(File))

        expect_any_instance_of(NativeExtFetcher).to receive(:http_get).
          with("s3.amazonaws.com", 443, true, "/skylight-agent-packages/skylight-native/1.0.0/skylight_linux-x86_64.tar.gz", an_instance_of(File)).
          and_return([ :success, checksum ])

        ret = fetch version: "1.0.0", target: @target, arch: "linux-x86_64", checksum: checksum
        expect(ret).to eq(true)
      end

    end

    context 'fetching unsuccessfully' do

      it 'verifies the checksum' do
        expect_any_instance_of(NativeExtFetcher).to receive(:http_get).
          with("s3.amazonaws.com", 443, true, "/skylight-agent-packages/skylight-native/1.0.0/skylight_linux-x86_64.tar.gz", an_instance_of(File)).
          and_return([ :success, checksum ])

        ret = fetch version: "1.0.0", target: @target, arch: "linux-x86_64", checksum: "abcdefghijklmnop"

        expect(ret).to be_nil
      end

    end

    def fetch(opts)
      NativeExtFetcher.fetch(opts)
    end

    def stub_ext_request(url=nil)
      url ||= "https://s3.amazonaws.com/skylight-agent-packages/skylight-native/1.0.0/skylight_linux-x86_64.tar.gz"
      stub_request(:get, url).
        to_return(:status => 200, :body => archive, :headers => {})
    end

    def expect_valid_output
      expect(Dir.entries(@target).sort).to eq(['.', '..', 'win'])
      expect(File.read("#{@target}/win")).to eq("win\n")
    end

  end
end
