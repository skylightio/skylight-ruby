require "spec_helper"

describe Skylight::Extensions::SourceLocation do
  def project_root
    File.expand_path(File.join(Gem.loaded_specs["skylight"].full_require_paths[0], ".."))
  end

  before do
    @instance_method_line = __LINE__ + 4
    stub_const(
      "MyConstant",
      Class.new do
        def an_instance_method
        end
      end
    )
  end

  let(:config) do
    instance_double(
      "Skylight::Config", 
      source_location_ignored_gems: %w[skylight], 
      root: Pathname.new(project_root), 
      :[] => nil
    ) 
  end

  let(:extension) { described_class.new(config) }

  describe "extension hooks" do
    describe "#process_instrument_options" do
      let(:opts) { {} }
      let(:meta) { {} }

      context "with no opts or meta" do
        specify do
          extension.process_instrument_options(opts, meta)
          expect(opts).to eq({})
          expect(meta).to have_key(:source_file)
          expect(meta).to have_key(:source_line)
        end
      end

      context "with source location in opts" do
        let(:opts) { { source_location: ["/path/to/file.rb", 10] } }

        specify do
          extension.process_instrument_options(opts, meta)
          expect(meta[:source_location]).to eq(["/path/to/file.rb", 10])
        end
      end

      context "with source file and line in opts" do
        let(:opts) { { source_file: "/path/to/file.rb", source_line: 10 } }

        specify do
          extension.process_instrument_options(opts, meta)
          expect(meta[:source_file]).to eq("/path/to/file.rb")
          expect(meta[:source_line]).to eq(10)
        end
      end
    end

    describe "#process_normalizer_meta" do
      let(:meta) { {} }
      let(:payload) { {} }

      specify do
        extension.process_normalizer_meta(payload, meta)
        expect(meta).to have_key(:source_file)
        expect(meta).to have_key(:source_line)
      end

      context "with sk_source_location in payload" do
        let(:payload) { { sk_source_location: ["/path/to/file.rb", 10] } }

        specify do
          extension.process_normalizer_meta(payload, meta)
          expect(meta[:source_file]).to eq("/path/to/file.rb")
          expect(meta[:source_line]).to eq(10)
        end
      end

      context "with source_location in meta" do
        let(:meta) { { source_location: ["/path/to/file.rb", 10] } }

        specify do
          extension.process_normalizer_meta(payload, meta)
          expect(meta[:source_file]).to eq("/path/to/file.rb")
          expect(meta[:source_line]).to eq(10)
        end
      end

      context "with source_location hint" do
        specify do
          extension.process_normalizer_meta(
            payload,
            meta,
            source_location_hint: [:instance_method, "MyConstant", "an_instance_method"]
          )

          expect(meta[:source_file]).to eq(__FILE__)
          expect(meta[:source_line]).to eq(@instance_method_line)
        end
      end
    end

    describe "#trace_preprocess_meta" do
      let(:meta) { { source_file: __FILE__, source_line: 5 } }

      specify do
        extension.trace_preprocess_meta(meta)
        expect(meta).to eq({ source_location: "spec/unit/extensions/source_location_spec.rb:5" })
      end

      def sanitize(file, line)
        meta = { source_file: file, source_line: line }
        extension.trace_preprocess_meta(meta)
        meta[:source_location]
      end

      it "reports gem paths by gem name only" do
        expect(sanitize(gem_path, 5)).to eq("rspec-core")
      end

      it "does not report paths outside the project or gems" do
        expect(sanitize(outside_path, 5)).to be_nil
      end

      it "classifies each path once, but keeps distinct lines distinct" do
        expect(extension).to receive(:compute_path_info).twice.and_call_original

        expect(sanitize(project_path.dup, 5)).to eq("app/models/user.rb:5")
        expect(sanitize(project_path.dup, 6)).to eq("app/models/user.rb:6")
        expect(sanitize(project_path.dup, nil)).to eq("app/models/user.rb")
        expect(sanitize(outside_path, 5)).to be_nil
        expect(sanitize(outside_path, 5)).to be_nil
      end

      it "clears the path cache when it reaches its limit" do
        stub_const("#{described_class}::PATH_CACHE_MAX_SIZE", 2)
        expect(extension).to receive(:compute_path_info).exactly(4).times.and_call_original

        sanitize(project_path, 1)
        sanitize(gem_path, 1)
        sanitize(outside_path, 1) # cache full; cleared before adding
        sanitize(project_path, 1)
      end
    end
  end

  let(:project_path) { File.join(project_root, "app/models/user.rb") }
  let(:gem_path) { File.join(Gem.loaded_specs["rspec-core"].full_require_paths[0], "rspec/core/example.rb") }
  let(:outside_path) { "/not/a/project/file.rb" }

  describe "finding the caller" do
    def location(path, lineno)
      instance_double(Thread::Backtrace::Location, absolute_path: path, lineno: lineno)
    end

    let(:locations) { [location(nil, 1), location(outside_path, 2), location(project_path, 3), location(gem_path, 4)] }

    before do
      allow(Kernel).to receive(:caller_locations).with(4..described_class::MAX_CALLER_DEPTH).and_return(locations)
    end

    def process_trace_meta
      {}.tap { |meta| extension.process_trace_meta(meta) }
    end

    it "uses the first frame in the project or a non-ignored gem" do
      expect(process_trace_meta).to eq({ source_file: project_path, source_line: 3 })
    end

    it "uses gem frames" do
      locations.delete_at(2)
      expect(process_trace_meta).to eq({ source_file: gem_path, source_line: 4 })
    end

    it "does not set a location when no frame matches" do
      locations.slice!(2..)
      expect(process_trace_meta).to eq({})
    end

    it "classifies each frame's path once" do
      expect(extension).to receive(:compute_path_info).twice.and_call_original # outside_path, project_path

      3.times { expect(process_trace_meta).to eq({ source_file: project_path, source_line: 3 }) }
    end
  end
end
