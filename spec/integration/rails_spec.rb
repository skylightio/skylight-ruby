require 'spec_helper'

enable = false
begin
  require 'rails'
  require 'action_controller/railtie'
  require 'skylight/railtie'
  enable = true
rescue LoadError
  puts "[INFO] Skipping rails integration specs"
end

if enable

  describe 'Rails integration' do

    def run_in_isolation(&blk)
      read, write = IO.pipe
      read.binmode
      write.binmode

      pid = fork do
        read.close

        test_result = begin
          yield
        rescue Exception => e
          e
        end

        result = Marshal.dump(test_result)

        write.puts [result].pack("m")
        exit!
      end

      write.close
      result = read.read
      Process.wait2(pid)
      Marshal.load(result.unpack("m")[0])
    end

    def set_env
      ENV['SKYLIGHT_AUTHENTICATION']       = "lulz"
      ENV['SKYLIGHT_BATCH_FLUSH_INTERVAL'] = "1"
      ENV['SKYLIGHT_REPORT_URL']           = "http://127.0.0.1:#{port}/report"
      ENV['SKYLIGHT_REPORT_HTTP_DEFLATE']  = "false"
      ENV['SKYLIGHT_AUTH_URL']             = "http://127.0.0.1:#{port}/agent"
      ENV['SKYLIGHT_VALIDATION_URL']       = "http://127.0.0.1:#{port}/agent/config"
      ENV['SKYLIGHT_AUTH_HTTP_DEFLATE']    = "false"
      ENV['SKYLIGHT_ENABLE_SEGMENTS']      = "true"

      if ENV['DEBUG']
        ENV['SKYLIGHT_ENABLE_TRACE_LOGS']    = "true"
        ENV['SKYLIGHT_LOG_FILE']             = "-"
      end
    end

    after :each do
      # TODO: Do we need this?
      Skylight.stop!
    end

    def boot
      require 'support/rails_app'
      set_env
      pre_boot
      MyApp.boot
    end

    around(:each) do |example|
      ret = run_in_isolation do
        boot
        example.run
        example.executed?
      end

      if ret.is_a?(Exception)
        raise ret
      end

      example.instance_variable_set(:@executed, ret)
    end

    shared_examples "with agent" do

      context "configuration" do

        it "sets log file" do
          expect(Skylight.instrumenter.config['log_file']).to eq(MyApp.root.join('log/skylight.log').to_s)
        end

        context "on heroku" do

          def pre_boot
            ENV['SKYLIGHT_HEROKU_DYNO_INFO_PATH'] = File.expand_path('../../../skylight-core/spec/support/heroku_dyno_info_sample', __FILE__)
          end

          it "recognizes heroku" do
            expect(Skylight.instrumenter.config).to be_on_heroku
          end

          it "leaves log file as STDOUT" do
            expect(Skylight.instrumenter.config['log_file']).to eq('-')
          end

        end

      end

      it 'successfully calls into rails' do
        res = call MyApp, env('/users')
        expect(res).to eq(["Hello"])

        server.wait resource: '/report'

        batch = server.reports[0]
        expect(batch).to_not be nil
        expect(batch.endpoints.count).to eq(1)
        endpoint = batch.endpoints[0]

        segment = Rails.version =~ /^4\./ ? 'html' : 'text'
        expect(endpoint.name).to eq("UsersController#index<sk-segment>#{segment}</sk-segment>")
        expect(endpoint.traces.count).to eq(1)
        trace = endpoint.traces[0]

        app_spans = trace.spans.map{|s| [s.event.category, s.event.title] }.select{|s| s[0] =~ /^app./ }
        expect(app_spans).to eq([
          ["app.rack.request", nil],
          ["app.controller.request", "UsersController#index"],
          ["app.method", "Check authorization"],
          ["app.method", "UsersController#index"],
          ["app.inside", nil],
          ["app.zomg", nil]
        ])
      end

      it 'successfully instruments middleware', :middleware_probe do
        call MyApp, env('/users')
        server.wait resource: '/report'

        trace = server.reports[0].endpoints[0].traces[0]

        app_and_rack_spans = trace.spans.map{|s| [s.event.category, s.event.title] }.select{|s| s[0] =~ /^(app|rack)./ }

        # We know the first one
        expect(app_and_rack_spans[0]).to eq(["app.rack.request", nil])

        # But the middlewares will be variable, depending on the Rails version
        count = 0
        while true do
          break if app_and_rack_spans[count+1][0] != "rack.middleware"
          count += 1
        end

        # We should have at least 2, but in reality a lot more
        expect(count).to be > 2

        # This one should be in all versions
        expect(app_and_rack_spans).to include(["rack.middleware", "Anonymous Middleware"], ["rack.middleware", "CustomMiddleware"])

        # Check the rest
        expect(app_and_rack_spans[(count+1)..-1]).to eq([
          ["rack.app", "ActionDispatch::Routing::RouteSet"],
          ["app.controller.request", "UsersController#index"],
          ["app.method", "Check authorization"],
          ["app.method", "UsersController#index"],
          ["app.inside", nil],
          ["app.zomg", nil]
        ])
      end

      it 'successfully names requests handled by middleware', :middleware_probe do
        res = call MyApp, env('/middleware')
        expect(res).to eq(["CustomMiddleware"])

        server.wait resource: '/report'

        batch = server.reports[0]
        expect(batch).to_not be nil
        expect(batch.endpoints.count).to eq(1)
        endpoint = batch.endpoints[0]

        expect(endpoint.name).to eq("CustomMiddleware")
      end

      it 'successfully names requests handled by anonymous middleware', :middleware_probe do
        res = call MyApp, env('/anonymous')
        expect(res).to eq(["Anonymous"])

        server.wait resource: '/report'

        batch = server.reports[0]
        expect(batch).to_not be nil
        expect(batch.endpoints.count).to eq(1)
        endpoint = batch.endpoints[0]

        expect(endpoint.name).to eq("Anonymous Middleware")
      end

      context "with middleware_position" do

        def pre_boot
          MyApp.config.skylight.middleware_position = { after: CustomMiddleware }
        end

        it 'does not instrument middleware if Skylight position is after', :middleware_probe do
          call MyApp, env('/users')
          server.wait resource: '/report'

          trace = server.reports[0].endpoints[0].traces[0]

          titles = trace.spans.map{ |s| s.event.title }

          # If Skylight runs after CustomMiddleware, we shouldn't see it
          expect(titles).to_not include("CustomMiddleware")
        end

      end

      context "middleware that don't conform to Rack SPEC" do

        it "doesn't report middleware that don't close body", :middleware_probe do
          ENV['SKYLIGHT_RAISE_ON_ERROR'] = nil

          expect_any_instance_of(Skylight::Core::Instrumenter).to_not receive(:process)

          call MyApp, env('/non-closing')
        end

        it "handles middleware that returns a non-array that is coercable", :middleware_probe do
          ENV['SKYLIGHT_RAISE_ON_ERROR'] = nil

          call MyApp, env('/non-array')
          server.wait resource: '/report'

          trace = server.reports[0].endpoints[0].traces[0]

          titles = trace.spans.map{ |s| s.event.title }

          expect(titles).to include("NonArrayMiddleware")
        end

      end

      it 'sets correct segment' do
        res = call MyApp, env('/users/1.json')
        expect(res).to eq([{ hola: '1' }.to_json])

        server.wait resource: '/report'

        batch = server.reports[0]
        expect(batch).to_not be nil
        expect(batch.endpoints.count).to eq(1)
        endpoint = batch.endpoints[0]
        expect(endpoint.name).to eq("UsersController#show<sk-segment>json</sk-segment>")
      end

      it 'sets rendered segment, not requested' do
        res = call MyApp, env('/users/1', 'HTTP_ACCEPT' => '*/*')
        expect(res).to eq([{ hola: '1' }.to_json])

        server.wait resource: '/report'

        batch = server.reports[0]
        expect(batch).to_not be nil
        expect(batch.endpoints.count).to eq(1)
        endpoint = batch.endpoints[0]
        expect(endpoint.name).to eq("UsersController#show<sk-segment>json</sk-segment>")
      end

      it 'sets correct segment for exceptions' do
        # Turn off for this test, since it will log a ton, due to the mock
        ENV['SKYLIGHT_RAISE_ON_ERROR'] = nil

        # TODO: This native_span_set_exception stuff should probably get its own test
        # NOTE: This tests handling by the Subscriber. The Middleware probe may catch the exception again.
        args = [anything]
        args << (Rails::VERSION::MAJOR >= 5 ? an_instance_of(RuntimeError) : nil)
        args << ["RuntimeError", "Fail!"]

        allow_any_instance_of(Skylight::Trace).to \
          receive(:native_span_set_exception).and_call_original

        expect_any_instance_of(Skylight::Trace).to \
          receive(:native_span_set_exception).with(*args).once.and_call_original

        res = call MyApp, env('/users/failure')
        expect(res).to be_empty

        server.wait resource: '/report'

        batch = server.reports[0]
        expect(batch).to_not be nil
        expect(batch.endpoints.count).to eq(1)
        endpoint = batch.endpoints[0]
        expect(endpoint.name).to eq("UsersController#failure<sk-segment>error</sk-segment>")
      end

      it 'sets correct segment for handled exceptions' do
        status, headers, body = call_full MyApp, env('/users/handled_failure')
        expect(status).to eq(500)
        expect(body).to eq([{ error: "Handled!" }.to_json])

        server.wait resource: '/report'

        batch = server.reports[0]
        expect(batch).to_not be nil
        expect(batch.endpoints.count).to eq(1)
        endpoint = batch.endpoints[0]

        expect(endpoint.name).to eq("UsersController#handled_failure<sk-segment>error</sk-segment>")
      end

      it 'sets correct segment for `head`' do
        status, headers, body = call_full MyApp, env('/users/header')
        expect(status).to eq(200)
        expect(body[0].strip).to eq('') # Some Rails versions have a space, some don't

        server.wait resource: '/report'

        batch = server.reports[0]
        expect(batch).to_not be nil
        expect(batch.endpoints.count).to eq(1)
        endpoint = batch.endpoints[0]

        expect(endpoint.name).to eq("UsersController#header")

        expect(endpoint.traces.count).to eq(1)
        trace = endpoint.traces[0]
        names = trace.spans.map { |s| s.event.category }

        expect(names.length).to be >= 3
        expect(names).to include('app.zomg')
        expect(names[0]).to eq('app.rack.request')
      end

      it 'sets correct segment for 4xx responses' do
        status, headers, body = call_full MyApp, env('/users/status?status=404')
        expect(status).to eq(404)
        expect(body).to eq(['404'])

        server.wait resource: '/report'

        batch = server.reports[0]
        expect(batch).to_not be nil
        expect(batch.endpoints.count).to eq(1)
        endpoint = batch.endpoints[0]
        expect(endpoint.name).to eq("UsersController#status<sk-segment>error</sk-segment>")
      end

      it 'sets correct segment for 5xx responses' do
        status, headers, body = call_full MyApp, env('/users/status?status=500')
        expect(status).to eq(500)
        expect(body).to eq(['500'])

        server.wait resource: '/report'

        batch = server.reports[0]
        expect(batch).to_not be nil
        expect(batch.endpoints.count).to eq(1)
        endpoint = batch.endpoints[0]
        expect(endpoint.name).to eq("UsersController#status<sk-segment>error</sk-segment>")
      end

      it 'sets correct segment when no template is found' do
        status, headers, body = call_full MyApp, env('/users/no_template')

        if Rails.version =~ /^4\./
          expect(status).to eq(500)
        else
          expect(status).to eq(406)
        end

        expect(body[0]).to be_blank

        server.wait resource: '/report'

        batch = server.reports[0]
        expect(batch).to_not be nil
        expect(batch.endpoints.count).to eq(1)
        endpoint = batch.endpoints[0]
        expect(endpoint.name).to eq("UsersController#no_template<sk-segment>error</sk-segment>")
      end

      it 'sets correct segment with variant' do
        res = call MyApp, env('/users/1.json?tablet=1')
        expect(res).to eq([{ hola_tablet: '1' }.to_json])

        server.wait resource: '/report'

        batch = server.reports[0]
        expect(batch).to_not be nil
        expect(batch.endpoints.count).to eq(1)
        endpoint = batch.endpoints[0]
        expect(endpoint.name).to eq("UsersController#show<sk-segment>json+tablet</sk-segment>")
      end

      it 'sets correct segment for `head` with variant' do
        status, headers, body = call_full MyApp, env('/users/header?tablet=1', 'HTTP_ACCEPT' => 'application/json')
        expect(status).to eq(200)
        expect(body[0].strip).to eq('') # Some Rails versions have a space, some don't

        server.wait resource: '/report'

        batch = server.reports[0]
        expect(batch).to_not be nil
        expect(batch.endpoints.count).to eq(1)
        endpoint = batch.endpoints[0]
        expect(endpoint.name).to eq("UsersController#header")
      end

      it 'can instrument metal controllers' do
        call MyApp, env('/metal')

        server.wait resource: '/report'

        batch = server.reports[0]
        expect(batch).to_not be nil
        expect(batch.endpoints.count).to eq(1)
        endpoint = batch.endpoints[0]
        expect(endpoint.name).to eq("MetalController#show<sk-segment>html</sk-segment>")
        expect(endpoint.traces.count).to eq(1)
        trace = endpoint.traces[0]

        names = trace.spans.map { |s| s.event.category }

        expect(names.length).to be >= 1
        expect(names[0]).to eq('app.rack.request')
      end

    end

    context "activated from application.rb", :agent do

      def pre_boot
        MyApp.config.skylight.environments << 'development'

        start_server

        stub_config_validation
        stub_session_request
      end

      it_behaves_like 'with agent'
    end

    context "activated from ENV", :agent do

      def pre_boot
        ENV['SKYLIGHT_ENABLED'] = "true"

        start_server

        stub_config_validation
        stub_session_request
      end

      it_behaves_like 'with agent'
    end

    shared_examples "without agent" do

      # Is this running at the right time?
      before :each do
        # Sanity check that we are indeed running without an active agent
        expect(Skylight.instrumenter).to be_nil
      end

      it "allows calls to Skylight.instrument" do
        expect(call(MyApp, env('/users'))).to eq(["Hello"])
      end

      it "supports Skylight::Helpers" do
        expect(call(MyApp, env('/users/1'))).to eq(["Hola: 1"])
      end

    end

    context "without configuration" do
      def pre_boot; end

      it_behaves_like 'without agent'
    end

    context "deactivated from ENV" do
      def pre_boot
        ENV['SKYLIGHT_ENABLED'] = "false"
        MyApp.config.skylight.environments << 'development'
      end

      it_behaves_like 'without agent'
    end


    def call_full(app, env)
      resp = app.call(env)
      consume(resp)
      resp
    end

    def call(app, env)
      call_full(app, env)[2]
    end

    def env(path = '/', opts = {})
      Rack::MockRequest.env_for(path, opts)
    end

    def consume(resp)
      data = []
      resp[2].each{|p| data << p }
      resp[2].close if resp[2].respond_to?(:close)
      resp[2] = data
      resp
    end

  end
end
