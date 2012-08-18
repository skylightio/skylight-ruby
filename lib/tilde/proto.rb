require 'digest/md5'

module Tilde
  # TODO: Handle string encodings
  #
  class Proto
    include Util::Bytes

    MAX_STRINGS    = 250
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

        append_string(b, @endpoint)

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

    def write(out, sample)
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

      puts "~~~~~~~~ SEGMENTS: #{traces.length} ~~~~~~~~~"

      # Write header
      out << [
        SAMPLE_MESSAGE_ID, # Sample set message ID
        traces.length      # Number of segments
      ].pack("C")

      # Track any strings that we have to send to the server
      missing = []

      # Write the segments
      traces.each do |endpoint, vals|
        tuples = @tuples[endpoint]

        missing << tuples.generate! unless tuples.md5

        # Write the segment head
        out << [tuples.md5, vals.length].pack('A*C')

        puts "~~~~~~~~ TRACES: #{vals.length} ~~~~~~~~~"

        vals.each do |trace|
          write_trace(out, trace, start, tuples)
        end

      end

      puts "~~~~~~~~ MISSING: #{missing.length} ~~~~~~~~~"

      unless missing.empty?
        out << [
          ENDPOINTS_MESSAGE_ID,
          missing.length
        ].pack('CC')

        missing.each do |cache|
          out << cache.bytes
        end
      end

      out
    end

  private

    def write_trace(out, trace, sample_start, tuples)
      out << trace.ident.bytes

      trace_start = trace.from

      # The time offset from the start of the trace group
      append_uint64(out, trace_start - sample_start)

      puts "~~~~~~~~ SPANS: #{trace.spans.length} ~~~~~~~~~"

      # Number of spans in the trace
      append_uint64(out, trace.spans.length)

      trace.spans.each_with_index do |s, idx|
        # The offset in the string table
        out << tuples.index(s.key) || UNKNOWN_STRING

        append_uint64(out, s.parent || idx)
        append_uint64(out, s.started_at - trace_start)
        append_uint64(out, s.ended_at - s.started_at)
      end
    end
  end
end
