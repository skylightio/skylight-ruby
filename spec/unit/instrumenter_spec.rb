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
      Skylight.start!(config).should be_truthy
    end

    it 'warns about unvalidated tokens' do
      stub_token_verification(500)
      Skylight.start!(config).should be_truthy
    end

    it 'fails with invalid token' do
      stub_token_verification(401)
      Skylight.start!(config).should be_falsey
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

        server.reports[0].endpoints.count.should == 1

        ep = server.reports[0].endpoints[0]
        ep.name.should == 'Testin'
        ep.traces.count.should == 1

        t = ep.traces[0]
        t.spans.count.should == 1
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

        server.reports[0].endpoints.count.should == 1

        ep = server.reports[0].endpoints[0]
        ep.name.should == 'Testin'
        ep.traces.count.should == 1

        t = ep.traces[0]
        t.spans.count.should == 1
        t.uuid.should == 'TODO'
        t.spans[0].should == span(
          event:      event('app.rack'),
          started_at: 0,
          duration:   10_000 )
      end

      it "handles un-lexable SQL" do
        bad_sql = "SELECT ???LOL??? ;;;NOTSQL;;;"

        Skylight.trace 'Testin', 'app.rack' do |t|
          ActiveSupport::Notifications.instrument('sql.active_record', name: "Load User", sql: bad_sql, binds: []) do
            clock.skip 1
          end
        end

        clock.unfreeze
        server.wait(count: 3)

        server.reports[0].endpoints.count.should == 1

        ep = server.reports[0].endpoints[0]
        ep.name.should == 'Testin'
        ep.traces.count.should == 1

        t = ep.traces[0]
        t.spans.count.should == 2
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

      it "handles SQL with binary data" do
        bad_sql = "SELECT ???LOL??? \xCE ;;;NOTSQL;;;".force_encoding("BINARY")
        encoded_sql = Base64.encode64(bad_sql)

        Skylight.trace 'Testin', 'app.rack' do |t|
          ActiveSupport::Notifications.instrument('sql.active_record', name: "Load User", sql: bad_sql, binds: []) do
            clock.skip 1
          end
        end

        clock.unfreeze
        server.wait(count: 3)

        server.reports[0].endpoints.count.should == 1

        ep = server.reports[0].endpoints[0]
        ep.name.should == 'Testin'
        ep.traces.count.should == 1

        t = ep.traces[0]
        t.spans.count.should == 2
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

      it "handles invalid string encodings" do
        bad_sql = "SELECT ???LOL??? \xCE ;;;NOTSQL;;;".force_encoding("UTF-8")
        encoded_sql = Base64.encode64(bad_sql)

        Skylight.trace 'Testin', 'app.rack' do |t|
          ActiveSupport::Notifications.instrument('sql.active_record', name: "Load User", sql: bad_sql, binds: []) do
            clock.skip 1
          end
        end

        clock.unfreeze
        server.wait(count: 3)

        server.reports[0].endpoints.count.should == 1

        ep = server.reports[0].endpoints[0]
        ep.name.should == 'Testin'
        ep.traces.count.should == 1

        t = ep.traces[0]
        t.spans.count.should == 2
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

  context 'standalone' do

    let(:log_path) { tmp('skylight.log') }
    let(:agent_strategy) { 'standalone' }

    it_behaves_like 'an instrumenter'

  end

end
