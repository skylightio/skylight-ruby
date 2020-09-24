require "spec_helper"
require "securerandom"
require "stringio"

describe "Skylight::Instrumenter", :http, :agent do
  before :each do
    @old_logger = config.logger
    config.logger = logger
  end

  after :each do
    config.logger = @old_logger
  end

  let :logger_out do
    StringIO.new
  end

  let :logger do
    log = Logger.new(logger_out)
    log.level = Logger::DEBUG
    log
  end

  context "boot" do
    before :each do
      @original_raise_on_error = ENV["SKYLIGHT_RAISE_ON_ERROR"]
      ENV["SKYLIGHT_RAISE_ON_ERROR"] = nil
    end

    after :each do
      Skylight.stop!
      ENV["SKYLIGHT_RAISE_ON_ERROR"] = @original_raise_on_error
    end

    it "validates the token" do
      stub_config_validation
      expect(Skylight.start!(config)).to be_truthy
    end

    it "fails with invalid token" do
      stub_config_validation(401)

      expect(Skylight.start!(config)).to be_falsey
      expect(logger_out.string).to include("Invalid authentication token")
    end

    it "fails with invalid component" do
      msg = "worker has not been approved"
      stub_config_validation(403, errors: { component: msg })
      expect(Skylight.start!(config)).to be_falsey
      expect(logger_out.string).to include(msg)
    end

    it "doesn't keep invalid config values" do
      config.set("test.enable_source_locations", true)
      stub_config_validation(422, { corrected: { enable_source_locations: false },
                                    errors: { enable_source_locations: "not allowed to be set" } })

      expect(Skylight.start!(config)).to be_truthy

      logger_out.rewind
      out = logger_out.read
      expect(out).to include("Invalid configuration")
      expect(out).to include("enable_source_locations: not allowed to be set")
      expect(out).to include("Updating config values:")
      expect(out).to include("setting enable_source_locations to false")

      expect(config.enable_source_locations?).to be_falsey
    end

    context "when server not reachable" do
      before(:each) do
        stub_config_validation(500)
      end

      it "starts anyway" do
        expect(Skylight.start!(config)).to be_truthy
        expect(logger_out.string).to include("Unable to reach server for config validation")
      end

      it "resets validated values to default" do
        config.set("test.enable_source_locations", true)

        expect(Skylight.start!(config)).to be_truthy

        logger_out.rewind
        out = logger_out.read
        puts out
        expect(out).to include("Unable to reach server for config validation")
        expect(out).to include("Updating config values:")
        expect(out).to include("setting enable_source_locations to false")

        expect(config.enable_source_locations?).to be_falsey
      end

      it "doesn't notify about values already at default" do
        expect(Skylight.start!(config)).to be_truthy

        logger_out.rewind
        out = logger_out.read
        expect(out).to include("Unable to reach server for config validation")
        expect(out).to_not include("Updating config values:")
        expect(out).to_not include("setting enable_source_locations to false")

        expect(config.enable_source_locations?).to be_falsey
      end

      context "with an exception" do
        before :each do
          allow_any_instance_of(Skylight::Util::HTTP).to receive(:do_request).and_raise("request failed")
        end

        it "starts anyway" do
          expect(Skylight.start!(config)).to be_truthy
          expect(logger_out.string).to include("Unable to reach server for config validation")
        end
      end
    end

    it "doesn't crash on failed config" do
      allow(config).to receive(:validate!).and_raise(Skylight::ConfigError.new("Test Failure"))
      expect(config).to receive(:log_warn).
        with("Unable to start Instrumenter due to a configuration error: Test Failure")

      expect do
        expect(Skylight.start!(config)).to be_falsey
      end.not_to raise_error
    end

    it "doesn't crash on failed start" do
      allow(Skylight::Instrumenter).to receive(:new).and_raise("Test Failure")
      expect(config).to receive(:log_error).
        with("Unable to start Instrumenter; msg=Test Failure; class=RuntimeError")

      expect do
        expect(Skylight.start!(config)).to be_falsey
      end.not_to raise_error
    end
  end

  shared_examples "an instrumenter" do
    context "when Skylight is running" do
      before :each do
        start!
        clock.freeze
      end

      after :each do
        Skylight.stop!
      end

      it "records the trace" do
        allow(SecureRandom).to receive(:uuid).once.and_return("test-uuid")

        Skylight.trace "Testin", "app.rack" do
          clock.skip 1
        end

        clock.unfreeze
        server.wait resource: "/report"

        expect(server.reports[0].endpoints.count).to eq(1)

        ep = server.reports[0].endpoints[0]
        expect(ep.name).to eq("Testin")
        expect(ep.traces.count).to eq(1)

        t = ep.traces[0]
        expect(t.uuid).to eq("test-uuid")
        expect(t.spans).to match([
          a_span_including(
            event:      an_exact_event(category: "app.rack"),
            started_at: 0,
            duration:   10_000
          )
        ])
      end

      it "ignores disabled parts of the trace" do
        allow(SecureRandom).to receive(:uuid).once.and_return("test-uuid")

        Skylight.trace "Testin", "app.rack" do
          Skylight.disable do
            ActiveSupport::Notifications.instrument(
              "sql.active_record",
              name: "Load User", sql: "SELECT * FROM posts", binds: []
            ) do
              clock.skip 1
            end
          end
        end

        clock.unfreeze
        server.wait resource: "/report"

        expect(server.reports[0].endpoints.count).to eq(1)

        ep = server.reports[0].endpoints[0]
        expect(ep.name).to eq("Testin")
        expect(ep.traces.count).to eq(1)

        t = ep.traces[0]
        expect(t.uuid).to eq("test-uuid")
        expect(t.spans).to match([
          a_span_including(
            event:      an_exact_event(category: "app.rack"),
            started_at: 0,
            duration:   10_000
          )
        ])
      end

      it "handles un-lexable SQL" do
        allow(SecureRandom).to receive(:uuid).once.and_return("test-uuid")

        bad_sql = "!!!"

        Skylight.trace "Testin", "app.rack" do
          ActiveSupport::Notifications.instrument("sql.active_record", name: "Load User", sql: bad_sql, binds: []) do
            clock.skip 1
          end
        end

        clock.unfreeze
        server.wait resource: "/report"

        expect(server.reports[0].endpoints.count).to eq(1)

        ep = server.reports[0].endpoints[0]
        expect(ep.name).to eq("Testin")
        expect(ep.traces.count).to eq(1)

        t = ep.traces[0]
        expect(t.uuid).to eq("test-uuid")

        expect(t.spans).to match([
          a_span_including(
            event:      an_exact_event(category: "app.rack"),
            started_at: 0,
            duration:   10_000
          ),
          a_span_including(
            parent:     0,
            event:      an_exact_event(category: "db.sql.query", title: "Load User"),
            started_at: 0,
            duration:   10_000
          )
        ])
      end

      it "handles SQL with binary data" do
        allow(SecureRandom).to receive(:uuid).once.and_return("test-uuid")

        bad_sql = "SELECT ???LOL??? \xCE ;;;NOTSQL;;;".force_encoding("BINARY")

        Skylight.trace "Testin", "app.rack" do
          ActiveSupport::Notifications.instrument("sql.active_record", name: "Load User", sql: bad_sql, binds: []) do
            clock.skip 1
          end
        end

        clock.unfreeze
        server.wait resource: "/report"

        expect(server.reports[0].endpoints.count).to eq(1)

        ep = server.reports[0].endpoints[0]
        expect(ep.name).to eq("Testin")
        expect(ep.traces.count).to eq(1)

        t = ep.traces[0]
        expect(t.uuid).to eq("test-uuid")

        expect(t.spans).to match([
          a_span_including(
            event:      an_exact_event(category: "app.rack"),
            started_at: 0,
            duration:   10_000
          ),
          a_span_including(
            parent:     0,
            event:      an_exact_event(category: "db.sql.query", title: "Load User"),
            started_at: 0,
            duration:   10_000
          )
        ])
      end

      it "handles invalid string encodings" do
        allow(SecureRandom).to receive(:uuid).once.and_return("test-uuid")

        bad_sql = "SELECT ???LOL??? \xCE ;;;NOTSQL;;;".force_encoding("UTF-8")

        Skylight.trace "Testin", "app.rack" do
          ActiveSupport::Notifications.instrument("sql.active_record", name: "Load User", sql: bad_sql, binds: []) do
            clock.skip 1
          end
        end

        clock.unfreeze
        server.wait resource: "/report"

        expect(server.reports[0].endpoints.count).to eq(1)

        ep = server.reports[0].endpoints[0]
        expect(ep.name).to eq("Testin")
        expect(ep.traces.count).to eq(1)

        t = ep.traces[0]
        expect(t.uuid).to eq("test-uuid")

        expect(t.spans).to match([
          a_span_including(
            event:      an_exact_event(category: "app.rack"),
            started_at: 0,
            duration:   10_000
          ),
          a_span_including(
            parent:     0,
            event:      an_exact_event(category: "db.sql.query", title: "Load User"),
            started_at: 0,
            duration:   10_000
          )
        ])
      end

      it "ignores endpoints" do
        config[:ignored_endpoint] = "foo#heartbeat"
        Skylight::Instrumenter.new(config)

        Skylight.trace "foo#bar", "app.rack" do
          clock.skip 1
        end

        Skylight.trace "foo#heartbeat", "app.rack" do
          clock.skip 1
        end

        clock.unfreeze
        server.wait resource: "/report"

        expect(server.reports[0]).to have(1).endpoints
        expect(server.reports[0].endpoints.map(&:name)).to eq(["foo#bar"])
      end

      it "ignores endpoints with segments" do
        config[:ignored_endpoint] = "foo#heartbeat"
        Skylight::Instrumenter.new(config)

        Skylight.trace "foo#bar", "app.rack", segment: "json" do
          clock.skip 1
        end

        Skylight.trace "foo#heartbeat", "app.rack", segment: "json" do
          clock.skip 1
        end

        clock.unfreeze
        server.wait resource: "/report"

        expect(server.reports[0]).to have(1).endpoints
        expect(server.reports[0].endpoints.map(&:name)).to eq(["foo#bar<sk-segment>json</sk-segment>"])
      end

      it "ignores multiple endpoints" do
        config[:ignored_endpoint] = "foo#heartbeat"
        config[:ignored_endpoints] = ["bar#heartbeat", "baz#heartbeat"]

        Skylight.trace "foo#bar", "app.rack" do
          clock.skip 1
        end

        %w[foo bar baz].each do |name|
          Skylight.trace "#{name}#heartbeat", "app.rack" do
            clock.skip 1
          end
        end

        clock.unfreeze
        server.wait resource: "/report"

        expect(server.reports[0]).to have(1).endpoints
        expect(server.reports[0].endpoints.map(&:name)).to eq(["foo#bar"])
      end

      it "ignores multiple endpoints with commas" do
        config[:ignored_endpoints] = "foo#heartbeat, bar#heartbeat,baz#heartbeat"

        Skylight.trace "foo#bar", "app.rack" do
          clock.skip 1
        end

        %w[foo bar baz].each do |name|
          Skylight.trace "#{name}#heartbeat", "app.rack" do
            clock.skip 1
          end
        end

        clock.unfreeze
        server.wait resource: "/report"

        expect(server.reports[0]).to have(1).endpoints
        expect(server.reports[0].endpoints.map(&:name)).to eq(["foo#bar"])
      end

      describe "#mute" do
        def spans
          server.reports[0].endpoints[0].traces[0].spans
        end

        context "unmute" do
          it "can unmute from within a block" do
            trace = Skylight.trace "Rack", "app.rack.request"
            a = b = c = d = e = f = nil
            a = trace.instrument "foo", nil, nil, mute_children: true

            # unmute is not intended to work on the trace, so if `mute_children` was set
            # by a parent span, unmute will have no effect.
            Skylight.unmute do
              clock.skip 0.1
              b = trace.instrument "bar"
              clock.skip 0.1
              c = trace.instrument "baz"
              clock.skip 0.1
              expect { trace.done(a) }.to change { trace.muted? }.from(true).to(false)
            end

            Skylight.mute do
              d = trace.instrument "wibble"
              clock.skip 0.1
              e = trace.instrument "wobble"
              clock.skip 0.1

              # Here we are unmuting the instrumenter, so we
              # expect the 'wubble' span to be added
              f = Skylight.unmute do
                trace.instrument "wubble"
              end

              clock.skip 0.1
              [f, e, d].each { |span| trace.done(span) }
            end

            trace.submit

            server.wait resource: "/report"

            expect(spans.count).to eq(3)
            expect(spans.map { |x| x.event.category }).to eq(["app.rack.request", "foo", "wubble"])
            expect(b).to be_nil
            expect(c).to be_nil
          end

          it "can stack mute and unmute blocks" do
            trace = Skylight.trace "Rack", "app.rack.request"
            Skylight.instrument(title: "foo") do
              Skylight.unmute do
                clock.skip 0.1
                Skylight.instrument(title: "bar") do
                  Skylight.mute do
                    clock.skip 0.1
                    Skylight.instrument(title: "baz") do
                      Skylight.unmute do
                        Skylight.instrument(title: "wibble") do
                          clock.skip 0.1
                        end
                      end
                    end
                  end

                  clock.skip 0.1
                end
              end

              Skylight.mute do
                Skylight.instrument(title: "wobble") do
                  Skylight.unmute do
                    clock.skip 0.1
                    Skylight.instrument(title: "wubble") do
                      Skylight.mute do
                        Skylight.instrument(title: "flob") do
                          clock.skip(0.1)
                        end
                      end
                    end
                  end
                end
              end
            end

            trace.submit

            server.wait resource: "/report"

            expect(spans.count).to eq(5)
            expect(spans.map { |x| x.event.title }).to eq([nil, "foo", "bar", "wibble", "wubble"])
          end
        end

        context "logging" do
          it "warns only once when trying to set a endpoint name from a muted block" do
            trace = Skylight.trace "Rack", "app.rack.request"
            a = trace.instrument "foo", nil, nil, mute_children: true

            trace.endpoint = "my endpoint name"
            trace.endpoint = "my endpoint name 2"
            trace.segment = "my segment name"
            trace.segment = "my segment name 2"

            expect { trace.done(a) }.to change { trace.muted? }.from(true).to(false)

            trace.submit

            server.wait resource: "/report"

            expect(spans.map { |x| x.event.category }).to eq(["app.rack.request", "foo"])
            expect(logger_out.string.lines.grep(/tried to set endpoint/).count).to eq(1)
            expect(logger_out.string.lines.grep(/tried to set segment/).count).to eq(1)
          end
        end
      end

      describe "#poison" do
        specify do
          expect(Skylight.instrumenter).to receive(:native_submit_trace) do
            raise Skylight::InstrumenterUnrecoverableError, "instrumenter is not running"
          end

          has_subscribers = lambda do
            %i[@subscriber @subscribers].reduce(Skylight.instrumenter) do |m, n|
              m.instance_variable_get(n)
            end.present?
          end

          Skylight.trace("Rack", "app.rack.request") do
          end

          expect(Skylight.instrumenter).to be_poisoned

          expect do
            # First trace on a poisoned instrumenter kicks off the shutdown thread
            Skylight.trace("Rack", "app.rack.request") do
            end

            # wait for unsubscribe
            Skylight.instance_variable_get(:@shutdown_thread).join
          end.to change(&has_subscribers).from(true).to(false)
        end
      end
    end
  end

  context "standalone" do
    let(:log_path) { tmp("skylight.log") }
    let(:agent_strategy) { "standalone" }

    it_behaves_like "an instrumenter"
  end
end
