require 'digest/md5'

module Tilde
  # TODO: Handle string encodings
  #
  class Proto
    include Util::Bytes

    MAX_STRINGS    = 250
    MASK_32        = 0xffffffff
    UNKNOWN_STRING = 0xff

    # Protocol constants
    PROTO_VERSION        = 1
    SAMPLE_MESSAGE_ID    = 0x00
    ENDPOINTS_MESSAGE_ID = 0x01

    class SpanTupleCache
      include Util::Bytes

      attr_reader :md5, :bytes

      def initialize(endpoint)
        @endpoint = endpoint
        @tuples   = {}
        @sorted   = []
        @dirty    = false
        @bytes    = nil
        @md5      = nil
      end

      def push(tuple)
        return if @tuples[tuple]
        return if @tuples.length > MAX_STRINGS

        @md5   = nil
        @bytes = nil
        @tuples[tuple] = true
        @sorted << tuple
        @sorted.sort!

        self
      end

      def index(tuple)
        @sorted.index(tuple)
      end

      # Doesn't support NULL bytes embedded in the string
      def generate!
        return self if md5

        puts "~~~~~~~~~~~~~~ SEGMENT (#{@endpoint}) #{@sorted.length} ~~~~~~~~~~~~~~"
        @sorted.each do |cat, desc|
          puts "  * #{cat} #{desc}"
        end

        b = ''

        # Append the number of tuples
        append_uint64(b, @sorted.length)

        @sorted.each do |cat, desc|
          append_string(b, cat)
          append_string(b, desc)
        end

        @bytes = b
        @md5 = Digest::MD5.digest(b)

        self
      end
    end

    def initialize
      @tuples = Hash.new { |h,k| h[k] = SpanTupleCache.new(k) }
    end

    def write(out, counts, sample)
      traces = Hash.new { |h,k| h[k] = [] }
      start  = nil

      # First ensure that all the strings are cached
      sample.each do |trace|
        tuples = @tuples[trace.endpoint]

        if start.nil? || start > trace.from
          start = trace.from
        end

        trace.spans.each do |span|
          tuples.push(span.key)
        end

        traces[trace.endpoint] << trace
      end

      missing = []

      @tuples.each do |endpoint, cache|
        missing << cache.generate! unless cache.md5
      end

      unless missing.empty?
        out << [
          ENDPOINTS_MESSAGE_ID,
          missing.length
        ].pack('CC')

        missing.each do |cache|
          out << cache.md5
          out << cache.bytes
        end
      end

      start = 5 * (start / 50_000)

      puts "~~~~~~~~ SEGMENTS: #{traces.length} - #{start} ~~~~~~~~~"

      # Write header
      out << [
        SAMPLE_MESSAGE_ID, # Sample set message ID
        start,
        traces.length      # Number of segments
      ].pack("CVC")

      # Write the segments
      traces.each do |endpoint, vals|
        tuples = @tuples[endpoint]

        # Write the segment head
        append_string(out, endpoint)
        append_uint64(out, counts[endpoint])

        out << [tuples.md5, vals.length].pack('A*C')

        puts "~~~~~~~~ TRACES: #{vals.length} ~~~~~~~~~"

        vals.each do |trace|
          write_trace(out, trace, start, tuples)
        end
      end

      out
    end

  private

    def write_trace(out, trace, sample_start, tuples)
      out << trace.ident.bytes

      diff_from = sample_start * 10_000

      puts "~~~~~~~~ SPANS: #{trace.spans.length} ~~~~~~~~~"

      # Number of spans in the trace
      append_uint64(out, trace.spans.length)

      trace.spans.each_with_index do |s, idx|
        # The offset in the string table
        out << tuples.index(s.key) || UNKNOWN_STRING

        append_uint64(out, s.parent || idx)
        append_uint64(out, s.started_at - diff_from)
        append_uint64(out, s.ended_at - s.started_at)

        diff_from = s.started_at
      end
    end
  end
end
