require "spec_helper"

describe SpecHelper::Messages::Span do
  def test_span(**attrs)
    span({
      event:      event("app.rack"),
      started_at: 0,
      duration:   10_000
    }.merge(attrs))
  end

  def test_annotation(key: 1)
    annotation(key: key, value: 123)
  end

  # NOTE: this spec documents the custom equality method defined on deserialized spans.
  # TLDR, if one or both compared spans does not have annotations, we skip that key for comparison.
  #
  # If we determine that object allocation is a stable enough value across supported architectures
  # and does not fluctuate between test runs, we should consider adding these annotations to the
  # expectations where they are used, at which point this spec should be deleted.
  describe "equality behavior" do
    specify { expect(test_span).to eq(test_span) }
    specify { expect(test_span(started_at: 1)).not_to eq(test_span) }
    specify do
      expect(::Kernel).to receive(:warn).with(a_string_matching("ignoring annotations"))
      expect(test_span(annotations: [test_annotation])).to eq(test_span)
    end

    specify do
      expect(::Kernel).to receive(:warn).with(a_string_matching("ignoring annotations"))
      expect(test_span).to eq(test_span(annotations: [test_annotation]))
    end

    specify do
      annotation1 = test_annotation(key: 1)
      annotation2 = test_annotation(key: 2)
      expect(test_span(annotations: [annotation1])).not_to eq(test_span(annotations: [annotation2]))
    end
  end
end
