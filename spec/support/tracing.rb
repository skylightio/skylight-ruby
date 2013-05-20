module SpecHelper

  def trace
    @trace ||= Skylight::Trace.new
  end

  def span(i)
    trace.spans[i]
  end

end
