require "spec_helper"

describe Skylight::Extensions::SourceLocation do
  class MyConstant
    def an_instance_method; end
  end

  def project_root
    File.expand_path(
      File.join(
        Gem.loaded_specs["skylight"].full_require_paths[0],
        ".."
      )
    )
  end

  let(:config) do
    OpenStruct.new(
      source_location_ignored_gems: %w[skylight],
      root:                         Pathname.new(project_root)
    )
  end

  let(:extension) do
    described_class.new(config)
  end

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
          expect(meta[:source_line]).to eq(5)
        end
      end
    end

    describe "#trace_preprocess_meta" do
      let(:meta) do
        {
          source_file: __FILE__,
          source_line: 5
        }
      end

      specify do
        extension.trace_preprocess_meta(meta)
        expect(meta).to eq({
          source_location: "spec/unit/extensions/source_location_spec.rb:5"
        })
      end
    end
  end
end
