
RSpec::Matchers.define :happen do |timeout = 1, interval = 0.1|

  match do |blk|
    res = false
    start = Time.now

    while timeout > Time.now - start
      if blk.call
        res = true
        break
      end

      sleep interval
    end

    res
  end

  failure_message_for_should do
    "expected block to happen but it didn't"
  end

  failure_message_for_should_not do
    "expected block not to happen but it did"
  end

end
