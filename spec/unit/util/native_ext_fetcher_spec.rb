require 'spec_helper'

module Skylight::Util
  describe NativeExtFetcher do

    let :archive do
      compress("win")
    end

    let :checksum do
      Digest::SHA2.hexdigest(archive)
    end

    context 'fetching successfully' do

      it 'fetches the native extension' do
        NativeExtFetcher.should_receive(:http_get).
          with("github.com", 443, true, "/skylightio/skylight-rust/releases/download/1.0.0/libskylight.1.0.0.linux-x86_64.a.gz").
          and_return([ :success, archive ])

        ret = fetch version: "1.0.0", arch: "linux-x86_64", checksum: checksum

        ret.should == "win"
      end

      it 'follows redirects' do
        NativeExtFetcher.should_receive(:http_get).
          with("github.com", 443, true, "/skylightio/skylight-rust/releases/download/1.0.0/libskylight.1.0.0.linux-x86_64.a.gz").
          and_return([ :redirect, "https://example.org/zomg/bar.gz" ])

        NativeExtFetcher.should_receive(:http_get).
          with("example.org", 443, true, "/zomg/bar.gz").
          and_return([ :success, archive ])

        ret = fetch version: "1.0.0", arch: "linux-x86_64", checksum: checksum

        ret.should == "win"
      end

      it 'retries on failure' do
        NativeExtFetcher.should_receive(:http_get) { raise "nope" }.
          with("github.com", 443, true, "/skylightio/skylight-rust/releases/download/1.0.0/libskylight.1.0.0.linux-x86_64.a.gz")

        NativeExtFetcher.should_receive(:http_get).
          with("github.com", 443, true, "/skylightio/skylight-rust/releases/download/1.0.0/libskylight.1.0.0.linux-x86_64.a.gz").
          and_return([ :success, archive ])

        ret = fetch version: "1.0.0", arch: "linux-x86_64", checksum: checksum

        ret.should == "win"
      end

      it 'writes the archive to the specified location' do
        NativeExtFetcher.should_receive(:http_get).
          with("github.com", 443, true, "/skylightio/skylight-rust/releases/download/1.0.0/libskylight.1.0.0.linux-x86_64.a.gz").
          and_return([ :success, archive ])

        ret = fetch version: "1.0.0", arch: "linux-x86_64", target: tmp("skylight.a"), checksum: checksum

        ret.should == "win"
        File.read(tmp("skylight.a")).should == "win"
      end

    end

    context 'fetching unsuccessfully' do

      it 'verifies the checksum' do
        NativeExtFetcher.should_receive(:http_get).
          with("github.com", 443, true, "/skylightio/skylight-rust/releases/download/1.0.0/libskylight.1.0.0.linux-x86_64.a.gz").
          and_return([ :success, archive ])

        ret = fetch version: "1.0.0", arch: "linux-x86_64", checksum: "abcdefghijklmnop"

        ret.should be_nil
      end

    end

    def fetch(opts)
      NativeExtFetcher.fetch(opts)
    end

    def compress(body)
      Gzip.compress(body)
    end

  end
end
