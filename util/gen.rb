$:.unshift File.expand_path('../gen',    __FILE__)
$:.unshift File.expand_path('../../lib', __FILE__)

module Gen
  require 'tilde'
  require 'basic'

  include Tilde

  PARALLELISM = 50

  threads = []
  instrumenter = Instrumenter.start!(Config.new)

  PARALLELISM.times do
    threads << Thread.new do
      while true
        STDOUT.print '.'
        STDOUT.flush
        instrumenter.trace("Rack") do
          Basic.new.gen
        end
      end
    end
  end

  begin
    threads.each(&:join)
  rescue Interrupt => e
    STDOUT.flush
    STDOUT.puts
    STDOUT.puts "Exiting!"
  end
end
