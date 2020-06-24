require "spec_helper"

# Tested here since it requires native
# FIXME: Switch to use mocking
describe Skylight::Instrumenter, :http, :agent do
  let :hello do
    double("hello")
  end

  context "when the instrumenter is running" do
    def test_config_values
      # rubocop:disable Naming/MemoizedInstanceVariableName
      @updated_test_config_values ||= super.merge(enable_source_locations: true)
      # rubocop:enable Naming/MemoizedInstanceVariableName
    end

    before :each do
      start!
      clock.freeze
      use_spec_root!
    end

    after :each do
      Skylight.stop!
    end

    it "tracks custom instrumentation metrics" do
      expect(hello).to receive(:hello)

      Skylight.trace "Testin", "app.rack.request" do
        clock.skip 0.1
        ret = Skylight.instrument category: "app.foo" do
          clock.skip 0.1
          hello.hello
          3
        end

        expect(ret).to eq(3)
      end

      clock.unfreeze
      server.wait resource: "/report"

      expect(server.reports[0].endpoints.count).to eq(1)

      ep = server.reports[0].endpoints[0]
      expect(ep.name).to eq("Testin")
      expect(ep.traces.count).to eq(1)

      t = ep.traces[0]
      expect(t.spans).to match([
        a_span_including(
          event:      an_exact_event(category: "app.rack.request"),
          started_at: 0,
          duration:   2_000
        ),
        a_span_including(
          parent:     0,
          event:      an_exact_event(category: "app.foo"),
          started_at: 1_000,
          duration:   1_000
        )
      ])
    end

    it "recategorizes unknown events as other" do
      Skylight.trace "Testin", "app.rack.request" do
        clock.skip 0.1
        Skylight.instrument category: "foo" do
          clock.skip 0.1
        end
      end

      clock.unfreeze
      server.wait resource: "/report"

      ep = server.reports[0].endpoints[0]
      t  = ep.traces[0]

      expect(t.spans[1]).to match(a_span_including(
                                    parent:     0,
                                    event:      an_exact_event(category: "other.foo"),
                                    started_at: 1_000,
                                    duration:   1_000
                                  ))
    end

    it "sets a default category" do
      Skylight.trace "Testin", "app.rack.request" do
        clock.skip 0.1
        Skylight.instrument title: "foo" do
          clock.skip 0.1
        end
      end

      clock.unfreeze
      server.wait resource: "/report"

      ep = server.reports[0].endpoints[0]
      t  = ep.traces[0]

      expect(t.spans[1]).to match(a_span_including(
                                    parent:     0,
                                    event:      an_exact_event(category: "app.block", title: "foo"),
                                    started_at: 1_000,
                                    duration:   1_000
                                  ))
    end

    context "source location" do
      it "tracks source location" do
        line = nil
        Skylight.trace "Testin", "app.rack.request" do
          clock.skip 0.1
          line = __LINE__ + 1
          Skylight.instrument category: "app.foo" do
            clock.skip 0.1
          end
        end

        clock.unfreeze
        server.wait resource: "/report"

        report = server.reports[0]

        source_file = Pathname.new(__FILE__).relative_path_from(spec_root)
        source_file_index = report.source_locations.index(source_file.to_s)

        span = report.endpoints[0].traces[0].spans[1]
        expect(span).to match(
          a_span_including(
            annotations: array_including(
              an_annotation(:SourceLocation, "#{source_file_index}:#{line}")
            )
          )
        )
      end

      it "allows a custom source file and line to be set" do
        Skylight.trace "Testin", "app.rack.request" do
          Skylight.instrument(source_file: "#{spec_root}/foo.rb", source_line: 10) {}
        end

        server.wait resource: "/report"

        report = server.reports[0]

        source_file_index = report.source_locations.index("foo.rb")

        span = report.endpoints[0].traces[0].spans[1]
        expect(span).to match(
          a_span_including(
            annotations: array_including(
              an_annotation(:SourceLocation, "#{source_file_index}:10")
            )
          )
        )
      end

      it "allows a custom source location to be set" do
        Skylight.trace "Testin", "app.rack.request" do
          Skylight.instrument(source_location: "foo.rb:10") {}
        end

        server.wait resource: "/report"


        report = server.reports[0]

        source_file_index = report.source_locations.index("foo.rb")

        span = report.endpoints[0].traces[0].spans[1]
        expect(span).to match(
          a_span_including(
            annotations: array_including(
              an_annotation(:SourceLocation, "#{source_file_index}:10")
            )
          )
        )
      end
    end

    class MyClass
      include Skylight::Helpers

      ONE_LINE = __LINE__ + 2
      instrument_method
      def one(arg)
        yield if block_given?
        arg
      end

      def two
        yield if block_given?
      end

      THREE_LINE = __LINE__ + 1
      def three
        yield if block_given?
      end

      CUSTOM_LINE = __LINE__ + 2
      instrument_method category: "app.winning", title: "Win"
      def custom
        yield if block_given?
      end

      instrument_method :three

      SINGLETON_LINE = __LINE__ + 2
      instrument_method
      def self.singleton_method
        yield if block_given?
      end

      SINGLETON_WITHOUT_OPTIONS_LINE = __LINE__ + 1
      def self.singleton_method_without_options
        yield if block_given?
      end
      instrument_class_method :singleton_method_without_options

      SINGLETON_WITH_OPTIONS_LINE = __LINE__ + 1
      def self.singleton_method_with_options
        yield if block_given?
      end
      instrument_class_method :singleton_method_with_options,
                              category: "app.singleton",
                              title:    "Singleton Method"

      ATTR_WRITER_LINE = __LINE__ + 1
      attr_accessor :myvar
      instrument_method :myvar=
    end

    it "tracks instrumented methods using the helper" do
      Skylight.trace "Testin", "app.rack.request" do
        inst = MyClass.new

        clock.skip 0.1
        ret = inst.one(:zomg) do
          clock.skip 0.1
          :one
        end
        expect(ret).to eq(:zomg)

        clock.skip 0.1
        inst.two { clock.skip 0.1 }

        clock.skip 0.1
        ret = inst.three do
          clock.skip 0.1
          :tres
        end
        expect(ret).to eq(:tres)

        clock.skip 0.1
        inst.custom { clock.skip 0.1 }

        clock.skip 0.1
        MyClass.singleton_method { clock.skip 0.1 }

        clock.skip 0.1
        MyClass.singleton_method_without_options { clock.skip 0.1 }

        clock.skip 0.1
        MyClass.singleton_method_with_options { clock.skip 0.1 }

        clock.skip 0.1
        ret = (inst.myvar = :foo)
        expect(ret).to eq(:foo)
        expect(inst.myvar).to eq(:foo)
      end

      clock.unfreeze
      server.wait resource: "/report"

      expect(server.reports[0].endpoints.count).to eq(1)

      report = server.reports.first

      ep = report.endpoints[0]
      expect(ep.name).to eq("Testin")
      expect(ep.traces.count).to eq(1)

      source_file = Pathname.new(__FILE__).relative_path_from(spec_root)
      source_file_index = report.source_locations.index(source_file.to_s)

      t = ep.traces[0]
      expect(t.spans).to match([
        a_span_including(
          event:      an_exact_event(category: "app.rack.request"),
          started_at: 0,
          duration:   15_000
        ),
        a_span_including(
          parent:      0,
          event:       an_exact_event(category: "app.method", title: "MyClass#one"),
          started_at:  1_000,
          duration:    1_000,
          annotations: array_including(
            an_annotation(:SourceLocation, "#{source_file_index}:#{MyClass::ONE_LINE}")
          )
        ),
        a_span_including(
          parent:      0,
          event:       an_exact_event(category: "app.method", title: "MyClass#three"),
          started_at:  5_000,
          duration:    1_000,
          annotations: array_including(
            an_annotation(:SourceLocation, "#{source_file_index}:#{MyClass::THREE_LINE}")
          )
        ),
        a_span_including(
          parent:      0,
          event:       an_exact_event(category: "app.winning", title: "Win"),
          started_at:  7_000,
          duration:    1_000,
          annotations: array_including(
            an_annotation(:SourceLocation, "#{source_file_index}:#{MyClass::CUSTOM_LINE}")
          )
        ),
        a_span_including(
          parent:      0,
          event:       an_exact_event(category: "app.method", title: "MyClass.singleton_method"),
          started_at:  9_000,
          duration:    1_000,
          annotations: array_including(
            an_annotation(:SourceLocation, "#{source_file_index}:#{MyClass::SINGLETON_LINE}")
          )
        ),
        a_span_including(
          parent:      0,
          event:       an_exact_event(category: "app.method", title: "MyClass.singleton_method_without_options"),
          started_at:  11_000,
          duration:    1_000,
          annotations: array_including(
            an_annotation(:SourceLocation, "#{source_file_index}:#{MyClass::SINGLETON_WITHOUT_OPTIONS_LINE}")
          )
        ),
        a_span_including(
          parent:      0,
          event:       an_exact_event(category: "app.singleton", title: "Singleton Method"),
          started_at:  13_000,
          duration:    1_000,
          annotations: array_including(
            an_annotation(:SourceLocation, "#{source_file_index}:#{MyClass::SINGLETON_WITH_OPTIONS_LINE}")
          )
        ),
        a_span_including(
          parent:      0,
          event:       an_exact_event(category: "app.method", title: "MyClass#myvar="),
          started_at:  15_000,
          duration:    0,
          annotations: array_including(
            an_annotation(:SourceLocation, "#{source_file_index}:#{MyClass::ATTR_WRITER_LINE}")
          )
        )
      ])
    end
  end

  context "when the instrumenter is not running" do
    it "does not break code" do
      expect(hello).to receive(:hello)

      Skylight.trace "Zomg", "app.rack.request" do |t|
        expect(t).to be_nil

        ret = Skylight.instrument category: "foo.bar" do |s|
          expect(s).to be_nil
          hello.hello
          1
        end

        expect(ret).to eq(1)
      end

      expect(Skylight.instrumenter).to be_nil
    end
  end
end
