module SpecHelper

  def trace
    @trace ||= Skylight::Messages::Trace::Builder.new
  end

  def span(i)
    trace.spans[i]
  end

end
