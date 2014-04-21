require 'spec_helper'
require 'securerandom'
require 'base64'
require "stringio"

describe "Skylight::Instrumenter", :http, :agent do

  context "boot" do

    let :logger_out do
      StringIO.new
    end

    let :logger do
      log = Logger.new(logger_out)
      log.level = Logger::DEBUG
      log
    end

    before :each do
      @old_logger = config.logger
      config.logger = logger
    end

    after :each do
      Skylight.stop!
      config.logger = @old_logger
    end

    it 'validates the token' do
      stub_token_verification
      Skylight.start!(config).should be_true
    end

    it 'warns about unvalidated tokens' do
      stub_token_verification(500)
      Skylight.start!(config).should be_true
      logger_out.string.should include("unable to validate authentication token")
    end

    it 'fails with invalid token' do
      stub_token_verification(401)
      Skylight.start!(config).should be_false
      logger_out.string.should include("failed to start instrumenter; msg=authentication token is invalid")
    end

    it "doesn't start if worker doesn't spawn" do
      worker = mock(spawn: nil)
      config.worker.should_receive(:build).and_return(worker)

      Skylight.start!(config).should be_false
    end

  end

  shared_examples 'an instrumenter' do

    context "when Skylight is running" do
      before :each do
        start!
        clock.freeze
      end

      after :each do
        Skylight.stop!
      end

      it 'records the trace' do
        Skylight.trace 'Testin', 'app.rack' do |t|
          clock.skip 1
        end

        clock.unfreeze
        server.wait(count: 3)

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

      it 'ignores disabled parts of the trace' do
        Skylight.trace 'Testin', 'app.rack' do |t|
          Skylight.disable do
            ActiveSupport::Notifications.instrument('sql.active_record', name: "Load User", sql: "SELECT * FROM posts", binds: []) do
              clock.skip 1
            end
          end
        end

        clock.unfreeze
        server.wait(count: 3)

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
        bad_sql = "SELECT ???LOL??? ;;;NOTSQL;;;"

        Skylight.trace 'Testin', 'app.rack' do |t|
          ActiveSupport::Notifications.instrument('sql.active_record', name: "Load User", sql: bad_sql, binds: []) do
            clock.skip 1
          end
        end

        clock.unfreeze
        server.wait(count: 4)

        error_request = server.requests[2]

        error_request["PATH_INFO"].should == "/agent/error"
        error = error_request["rack.input"]
        error['type'].should == "sql_parse"
        error['description'].should_not be_nil
        error['details'].keys.should == ['backtrace', 'payload', 'precalculated']
        error['details']['payload']['sql'].should == bad_sql

        server.reports[0].should have(1).endpoints

        ep = server.reports[0].endpoints[0]
        ep.name.should == 'Testin'
        ep.should have(1).traces

        t = ep.traces[0]
        t.should have(2).spans
        t.uuid.should == 'TODO'

        t.spans[0].should == span(
          event:      event('app.rack'),
          started_at: 0,
          duration:   10_000 )

        t.spans[1].should == span(
          parent:     0,
          event:      event('db.sql.query', 'Load User'),
          started_at: 0,
          duration:   10_000 )
      end

      it "sends error messages with binary data the Skylight Rails app" do
        bad_sql = "SELECT ???LOL??? \xCE ;;;NOTSQL;;;".force_encoding("BINARY")
        encoded_sql = Base64.encode64(bad_sql)

        Skylight.trace 'Testin', 'app.rack' do |t|
          ActiveSupport::Notifications.instrument('sql.active_record', name: "Load User", sql: bad_sql, binds: []) do
            clock.skip 1
          end
        end

        clock.unfreeze
        server.wait(count: 4)

        error_request = server.requests[2]
        error_request["PATH_INFO"].should == "/agent/error"
        error = error_request["rack.input"]
        error['type'].should == "sql_parse"
        error['description'].should_not be_nil
        error['details'].keys.should == ['backtrace', 'payload', 'precalculated']
        error['details']['payload']['sql'].should == encoded_sql

        server.reports[0].should have(1).endpoints

        ep = server.reports[0].endpoints[0]
        ep.name.should == 'Testin'
        ep.should have(1).traces

        t = ep.traces[0]
        t.should have(2).spans
        t.uuid.should == 'TODO'

        t.spans[0].should == span(
          event:      event('app.rack'),
          started_at: 0,
          duration:   10_000 )

        t.spans[1].should == span(
          parent:     0,
          event:      event('db.sql.query', 'Load User'),
          started_at: 0,
          duration:   10_000 )
      end

      it "sends error messages with invalid UTF-8 data to the Skylight Rails app" do
        bad_sql = "SELECT ???LOL??? \xCE ;;;NOTSQL;;;".force_encoding("UTF-8")
        encoded_sql = Base64.encode64(bad_sql)

        Skylight.trace 'Testin', 'app.rack' do |t|
          ActiveSupport::Notifications.instrument('sql.active_record', name: "Load User", sql: bad_sql, binds: []) do
            clock.skip 1
          end
        end

        clock.unfreeze
        server.wait(count: 4)

        error_request = server.requests[2]

        error_request["PATH_INFO"].should == "/agent/error"
        error = error_request["rack.input"]
        error['type'].should == "sql_parse"
        error['description'].should_not be_nil
        error['details'].keys.should == ['backtrace', 'payload', 'precalculated']
        error['details']['payload']['sql'].should == encoded_sql

        server.reports[0].should have(1).endpoints

        ep = server.reports[0].endpoints[0]
        ep.name.should == 'Testin'
        ep.should have(1).traces

        t = ep.traces[0]
        t.should have(2).spans
        t.uuid.should == 'TODO'

        t.spans[0].should == span(
          event:      event('app.rack'),
          started_at: 0,
          duration:   10_000 )

        t.spans[1].should == span(
          parent:     0,
          event:      event('db.sql.query', 'Load User'),
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
