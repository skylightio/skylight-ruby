require 'spec_helper'

module Skylight
  module Probes
    describe "Excon", :excon_probe do
      describe "Probe", :probes do

        it "is registered" do
          reg = Skylight::Probes.installed["Excon"]
          reg.klass_name.should == "Excon"
          reg.require_paths.should == ["excon"]
          reg.probe.should be_a(Skylight::Probes::Excon::Probe)
        end

        it "adds a middleware to Excon" do
          middlewares = ::Excon.defaults[:middlewares]

          middlewares.should include(Skylight::Probes::Excon::Middleware)

          # Verify correct positioning
          idx = middlewares.index(Skylight::Probes::Excon::Middleware)
          middlewares[idx+1].should == ::Excon::Middleware::Instrumentor
        end
      end

      describe "Middleware" do

        # This may be a bit overkill, but I'm trying to mock Excon somewhat accurately
        class TestConnection
          def initialize(middlewares=[])
            @error_calls = []
            @request_calls = []
            @response_calls = []

            # This is how Excon does it
            # https://github.com/geemus/excon/blob/b367b788b0cd71eb22107492496e1857497dd292/lib/excon/connection.rb#L260-L265
            @stack = middlewares.map do |middleware|
              lambda {|stack| middleware.new(stack)}
            end.reverse.inject(self) do |middlewares, middleware|
              middleware.call(middlewares)
            end
          end

          def error_call(datum)
            @error_calls << datum
          end

          def request_call(datum)
            @request_calls << datum
          end

          def response_call(datum)
            @response_calls << datum
          end

          def error(datum)
            @stack.error_call(datum)
          end

          def request(datum)
            @stack.request_call(datum)
          end

          def response(datum)
            @stack.response_call(datum)
          end
        end

        let :span do
          double("span", done: true)
        end

        let :conn do
          TestConnection.new([Skylight::Probes::Excon::Middleware])
        end

        it "instruments a successful request" do
          args = { category: "api.http.get",
                   title: "GET www.example.com",
                   annotations: {
                     method: "GET",
                     scheme: "http",
                     host:   "www.example.com",
                     port:   nil,
                     path:   "/",
                     query:  nil } }
          Skylight.should_receive(:instrument).with(args).and_return(span)
          span.should_receive(:done).once

          datum = { method: "get", scheme: "http", host: "www.example.com", path: "/" }
          conn.request(datum)
          conn.response(datum)
        end

        it "instruments an errored request" do
          args = { category: "api.http.get",
                   title: "GET www.example.com",
                   annotations: {
                     method: "GET",
                     scheme: "http",
                     host:   "www.example.com",
                     port:   nil,
                     path:   "/",
                     query:  nil } }
          Skylight.should_receive(:instrument).with(args).and_return(span)
          span.should_receive(:done).once

          datum = { method: "get", scheme: "http", host: "www.example.com", path: "/" }
          conn.request(datum)
          conn.error(datum)
        end

      end
    end
  end
end
