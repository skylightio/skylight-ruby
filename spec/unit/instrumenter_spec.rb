require 'spec_helper'
require 'securerandom'

describe Skylight::Instrumenter, :http do

  shared_examples 'an instrumenter' do

    context "when Skylight is running" do
      before :each do
        Skylight.start! config
        clock.freeze
      end

      after :each do
        Skylight.stop!
      end

      it 'records the trace' do
        stub_session_request

        Skylight.trace 'Testin', 'app.rack' do |t|
          clock.skip 1
        end

        clock.unfreeze
        server.wait(timeout: 2, count: 2)

        server.reports[0].should have(1).endpoints

        ep = server.reports[0].endpoints[0]
        ep.name.should == 'Testin'
        ep.should have(1).traces

        t = ep.traces[0]
        t.should have(1).spans
        t.uuid.should == 'TODO'
        t.spans[0].should == span(
          event:      event('app.rack'),
          started_at: 0,
          duration:   10_000 )
      end

      it "sends error messages to the Skylight Rails app" do
        stub_session_request

        bad_sql = "SELECT ???LOL??? ;;;NOTSQL;;;"

        Skylight.trace 'Testin', 'app.rack' do |t|
          ActiveSupport::Notifications.instrument('sql.active_record', name: "Load User", sql: bad_sql, binds: []) do
            clock.skip 1
          end
        end

        clock.unfreeze
        server.wait(timeout: 2, count: 3)

        server.requests[1]["REQUEST_PATH"].should == "/agent/error"
        error = server.requests[1]["rack.input"]
        JSON.parse(error).should == { "reason" => "sql_parse", "body" => bad_sql }

        server.reports[0].should have(1).endpoints

        ep = server.reports[0].endpoints[0]
        ep.name.should == 'Testin'
        ep.should have(1).traces

        t = ep.traces[0]
        t.should have(2).spans
        t.uuid.should == 'TODO'

        t.spans[1].should == span(
          event:      event('app.rack'),
          started_at: 0,
          duration:   10_000,
          children: 1 )

        t.spans[0].should == span(
          event:      event('db.sql.query', 'Load User'),
          annotations: annotation('skylight_error', :nested) do |n|
            n << annotation(nil, :string, "sql_parse")
            n << annotation(nil, :string, bad_sql)
          end,
          started_at: 0,
          duration:   10_000 )
      end
    end

    def with_endpoint(endpoint)
      config[:trace_info].current = Struct.new(:endpoint).new(endpoint)
      yield
    ensure
      config[:trace_info] = nil
    end

    it "limits unique descriptions to 100" do
      config[:trace_info] = Struct.new(:current).new
      instrumenter = Skylight::Instrumenter.new(config)

      with_endpoint("foo#bar") do
        100.times do
          description = SecureRandom.hex
          instrumenter.limited_description(description).should == description
        end

        description = SecureRandom.hex
        instrumenter.limited_description(description).should == Skylight::Instrumenter::TOO_MANY_UNIQUES
      end
    end

  end

  context 'embedded' do

    let(:agent_strategy) { 'embedded' }

    it_behaves_like 'an instrumenter'

  end

  context 'standalone' do

    let(:log_path) { tmp('skylight.log') }
    let(:agent_strategy) { 'standalone' }

    it_behaves_like 'an instrumenter'

  end unless defined?(JRUBY_VERSION)

end
