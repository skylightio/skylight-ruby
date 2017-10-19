module SpecHelper

  def create_probe
    Probe.new
  end

  class Probe
    attr_reader :install_count

    def initialize
      @install_count = 0
    end

    def install
      @install_count += 1
    end
  end
end