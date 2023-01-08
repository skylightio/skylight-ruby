require "spec_helper"

# Tested here since it requires native
# FIXME: Switch to use mocking
# NOTE: there are several overrides for stree/rubocop with respect to argument forwarding;
# we want to test all of these cases explicitly so please leave as-is.
# rubocop:disable Style/ArgumentsForwarding
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

        class MyClass 
          include Skylight::Helpers

          const_set(:ONE_LINE, __LINE__ + 2)
          instrument_method
          def one(arg)
            yield if block_given?
            arg
          end

          def two
            yield if block_given?
          end

          const_set(:THREE_LINE, __LINE__ + 1)
          def three
            yield if block_given?
          end

          const_set(:CUSTOM_LINE, __LINE__ + 2)
          instrument_method category: "app.winning", title: "Win"
          def custom
            yield if block_given?
          end

          instrument_method :three

          const_set(:SINGLETON_LINE, __LINE__ + 2)
          instrument_method
          def self.singleton_method
            yield if block_given?
          end

          const_set(:SINGLETON_WITHOUT_OPTIONS_LINE, __LINE__ + 1)
          def self.singleton_method_without_options
            yield if block_given?
          end
          instrument_class_method :singleton_method_without_options

          const_set(:SINGLETON_WITH_OPTIONS_LINE, __LINE__ + 1)
          def self.singleton_method_with_options
            yield if block_given?
          end
          instrument_class_method :singleton_method_with_options, category: "app.singleton", title: "Singleton Method"

          const_set(:ATTR_WRITER_LINE, __LINE__ + 1)
          attr_accessor :myvar

          instrument_method :myvar=

          instrument_method
          def method_with_mixed_args(arg1, opt1:, opt2: nil, &block)
            block.call(arg1) if opt2
          end

          instrument_method
          def method_with_ellipsis(...)
            ellipsis_receiver(...)
          end

          def method_with_ellipsis_control(...)
            ellipsis_receiver(...)
          end

          def ellipsis_receiver(arg1, opt1:, opt2:, **keywords)
            [arg1, opt1, opt2, keywords]
          end

          # below:
          #   `receiver` means a method we are delegating to; not instrumented
          #   `control` is a copy of the instrumented method

          # stree-ignore
          ruby2_keywords def ruby2_keywords_method(*args, &block)
            delegated_splat_receiver(*args, &block)
          end

          instrument_method :ruby2_keywords_method

          # stree-ignore
          ruby2_keywords def ruby2_keywords_control(*args, &block)
            delegated_splat_receiver(*args, &block)
          end


          instrument_method
          # stree-ignore
          ruby2_keywords def ruby2_keywords_method_with_deferred_instrumentation(*args, &block)
            delegated_splat_receiver(*args, &block)
          end

          instrument_method
          # stree-ignore
          def delegated_splat(*args, **kwargs, &block)
            delegated_splat_receiver(*args, **kwargs, &block)
          end

          instrument_method
          # stree-ignore
          def delegated_single_splat(*args, &block)
            delegated_single_splat_receiver(*args, &block)
          end

          # stree-ignore
          def delegated_splat_control(*args, **kwargs, &block)
            delegated_splat_receiver(*args, **kwargs, &block)
          end

          # stree-ignore
          def delegated_single_splat_control(*args, &block)
            delegated_single_splat_receiver(*args, &block)
          end

          # stree-ignore
          def delegated_splat_receiver(*args, **kwargs)
            { args: args, kwargs: kwargs }
          end

          # stree-ignore
          def delegated_single_splat_receiver(*args)
            args
          end

          instrument_method
          def optional_argument_default_hash(options = {})
            options[:arg1]
          end

          instrument_method
          def optional_argument_default_hash_kwargs(options = {}, **_kwargs)
            options[:arg1]
          end

          ruby2_keywords def pre_alias_ruby2_keywords_method(*args, &block)
            delegated_splat_receiver(*args, &block)
          end

          alias :aliased_ruby2_keywords_method :pre_alias_ruby2_keywords_method
          alias_method :"aliased_method_ruby2_keywords_method", :"pre_alias_ruby2_keywords_method"

          # __sk_singleton_class.class_eval <<~RUBY
          #   alias_method :"class_eval_alias_ruby2_keywords_method", :"pre_alias_ruby2_keywords_method"       # alias_method :"before_instrument_process", :"process"
          # RUBY
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
        ret =
          Skylight.instrument category: "app.foo" do
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
      expect(t.spans).to match(
        [
          a_span_including(event: an_exact_event(category: "app.rack.request"), started_at: 0, duration: 2_000),
          a_span_including(parent: 0, event: an_exact_event(category: "app.foo"), started_at: 1_000, duration: 1_000)
        ]
      )
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
      t = ep.traces[0]

      expect(t.spans[1]).to match(
        a_span_including(parent: 0, event: an_exact_event(category: "other.foo"), started_at: 1_000, duration: 1_000)
      )
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
      t = ep.traces[0]

      expect(t.spans[1]).to match(
        a_span_including(
          parent: 0,
          event: an_exact_event(category: "app.block", title: "foo"),
          started_at: 1_000,
          duration: 1_000
        )
      )
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
          a_span_including(annotations: array_including(an_annotation(:SourceLocation, "#{source_file_index}:#{line}")))
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
          a_span_including(annotations: array_including(an_annotation(:SourceLocation, "#{source_file_index}:10")))
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
          a_span_including(annotations: array_including(an_annotation(:SourceLocation, "#{source_file_index}:10")))
        )
      end
    end

    it "works with ruby 3 args" do
      arg1 = Object.new
      expect(arg1).to receive(:foo)

      Skylight.trace "Testing", "app.rack.request" do
        inst = MyClass.new
        inst.method_with_mixed_args(arg1, opt1: :one, opt2: true, &:foo)
      end
    end

    it "tracks instrumented methods using the helper" do
      Skylight.trace "Testin", "app.rack.request" do
        inst = MyClass.new

        clock.skip 0.1
        ret =
          inst.one(:zomg) do
            clock.skip 0.1
            :one
          end
        expect(ret).to eq(:zomg)

        clock.skip 0.1
        inst.two { clock.skip 0.1 }

        clock.skip 0.1
        ret =
          inst.three do
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
      expect(t.spans).to match(
        [
          a_span_including(event: an_exact_event(category: "app.rack.request"), started_at: 0, duration: 15_000),
          a_span_including(
            parent: 0,
            event: an_exact_event(category: "app.method", title: "MyClass#one"),
            started_at: 1_000,
            duration: 1_000,
            annotations: array_including(an_annotation(:SourceLocation, "#{source_file_index}:#{MyClass::ONE_LINE}"))
          ),
          a_span_including(
            parent: 0,
            event: an_exact_event(category: "app.method", title: "MyClass#three"),
            started_at: 5_000,
            duration: 1_000,
            annotations: array_including(an_annotation(:SourceLocation, "#{source_file_index}:#{MyClass::THREE_LINE}"))
          ),
          a_span_including(
            parent: 0,
            event: an_exact_event(category: "app.winning", title: "Win"),
            started_at: 7_000,
            duration: 1_000,
            annotations: array_including(an_annotation(:SourceLocation, "#{source_file_index}:#{MyClass::CUSTOM_LINE}"))
          ),
          a_span_including(
            parent: 0,
            event: an_exact_event(category: "app.method", title: "MyClass.singleton_method"),
            started_at: 9_000,
            duration: 1_000,
            annotations:
              array_including(an_annotation(:SourceLocation, "#{source_file_index}:#{MyClass::SINGLETON_LINE}"))
          ),
          a_span_including(
            parent: 0,
            event:
              an_exact_event(
                category: "app.method",
                title: "MyClass.singleton_method_without_options"
              ),
            started_at: 11_000,
            duration: 1_000,
            annotations:
              array_including(
                an_annotation(:SourceLocation, "#{source_file_index}:#{MyClass::SINGLETON_WITHOUT_OPTIONS_LINE}")
              )
          ),
          a_span_including(
            parent: 0,
            event: an_exact_event(category: "app.singleton", title: "Singleton Method"),
            started_at: 13_000,
            duration: 1_000,
            annotations:
              array_including(
                an_annotation(:SourceLocation, "#{source_file_index}:#{MyClass::SINGLETON_WITH_OPTIONS_LINE}")
              )
          ),
          a_span_including(
            parent: 0,
            event: an_exact_event(category: "app.method", title: "MyClass#myvar="),
            started_at: 15_000,
            duration: 0,
            annotations:
              array_including(an_annotation(:SourceLocation, "#{source_file_index}:#{MyClass::ATTR_WRITER_LINE}"))
          )
        ]
      )
    end

    context "method delegation" do
      it "works with ellipsis delegation" do
        obj = MyClass.new
        control = obj.method_with_ellipsis_control(:foo, opt1: 1, opt2: 2, opt3: 3)
        result = obj.method_with_ellipsis(:foo, opt1: 1, opt2: 2, opt3: 3)

        expect(control).to eq([:foo, 1, 2, { opt3: 3 }])
        expect(result).to eq(control)
      end

      it "works with ruby2_keywords (explicit instrument_method)" do
        obj = MyClass.new
        control = obj.ruby2_keywords_control(:positional, kw1: 1, kw2: 2)
        result = obj.ruby2_keywords_method(:positional, kw1: 1, kw2: 2)

        expect(control).to eq({ args: [:positional], kwargs: { kw1: 1, kw2: 2 } })
        expect(result).to eq(control)
      end

      # NOTE: There is a difference in the order of application of ruby2_keywords and the method_added
      # hooks. In Ruby 3.2, Skylight's method patcher only sees the method _before_ ruby2_keywords is applied,
      # meaning the aliased method never gets this flag set (only the outer, Skylight-defined wrapper gets it,
      # which is not what we really want).
      send(RUBY_VERSION.start_with?("3.2") ? :pending: :it, "works with ruby2_keywords (deferred instrument_method)") do
        obj = MyClass.new
        control = obj.ruby2_keywords_control(:positional, kw1: 1, kw2: 2)
        result = obj.ruby2_keywords_method_with_deferred_instrumentation(:positional, kw1: 1, kw2: 2)

        # ensure that this behaves as it would without delegation
        expect(control).to eq({ args: [:positional], kwargs: { kw1: 1, kw2: 2 } })
        expect(result).to eq(control)
      end

      it "works with delegated splats" do
        obj = MyClass.new
        control = obj.delegated_splat_control(:positional, kw1: 1, kw2: 2)
        result = obj.delegated_splat(:positional, kw1: 1, kw2: 2)

        expect(control).to eq({ args: [:positional], kwargs: { kw1: 1, kw2: 2 } })
        expect(result).to eq(control)
      end

      it "works with single splats" do
        obj = MyClass.new
        control = obj.delegated_single_splat_control(:positional, kw1: 1, kw2: 2)
        result = obj.delegated_single_splat(:positional, kw1: 1, kw2: 2)

        # all args in one array, options grouped as hash
        expect(control).to eq([:positional, { kw1: 1, kw2: 2 }])
        expect(result).to eq(control)
      end

      begin
        require "action_controller"

        it "works with hash-like objects, default arg" do
          obj = MyClass.new
          unpermitted_params = ActionController::Parameters.new(arg1: "foo")
          expect(obj.optional_argument_default_hash).to eq(nil)

          # unpermitted_params would raise an error on the implicit #to_hash
          expect(obj.optional_argument_default_hash(unpermitted_params)).to eq("foo")
        end

        it "works with hash-like objects, default arg with kwargs" do
          obj = MyClass.new
          unpermitted_params = ActionController::Parameters.new(arg1: "foo")
          expect(obj.optional_argument_default_hash_kwargs).to eq(nil)

          # unpermitted_params would raise an error on the implicit #to_hash

          if RUBY_VERSION.start_with?("2")
            # This is here primarily to document the issues with automatic keyword argument conversion,
            # and that the behavior is identical with or without Skylight's instrumentation.
            #
            expect { obj.before_instrument_optional_argument_default_hash_kwargs(unpermitted_params) }.to(
              raise_error(ActionController::UnfilteredParameters)
            )

            expect { obj.optional_argument_default_hash_kwargs(unpermitted_params) }.to(
              raise_error(ActionController::UnfilteredParameters)
            )
          else
            expect(obj.before_instrument_optional_argument_default_hash_kwargs(unpermitted_params)).to(eq("foo"))

            expect(obj.optional_argument_default_hash_kwargs(unpermitted_params)).to(eq("foo"))
          end
        end
      rescue LoadError
        puts "ActionController not present, skipping test"
      end
    end
  end

  context "when the instrumenter is not running" do
    it "does not break code" do
      expect(hello).to receive(:hello)

      Skylight.trace "Zomg", "app.rack.request" do |t|
        expect(t).to be_nil

        ret =
          Skylight.instrument category: "foo.bar" do |s|
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
# rubocop:enable Style/ArgumentsForwarding
