module Skylight
  module Worker
    # Represents the IPC client connection
    class Connection
      FRAME_HDR_LEN = 8

      attr_reader :sock, :throughput

      def initialize(sock)
        @sock = sock
        @len  = nil
        @buf  = ""

        # Metrics
        @throughput = Metrics::Meter.new
      end

      def read
        if msg = maybe_read_message
          return msg
        end

        if chunk = read_sock

          @buf << chunk

          if !@len && @buf.bytesize >= FRAME_HDR_LEN
            @len = read_len
          end

          maybe_read_message
        end
      end

      def cleanup
        # Any cleanup code here
      end

    private

      def read_len
        if len = @buf[4, 4]
          len.unpack("L")[0]
        end
      end

      def read_message_id
        if win = @buf[0, 4]
          win.unpack("L")[0]
        end
      end

      def maybe_read_message
        if @len && @buf.bytesize >= @len + FRAME_HDR_LEN
          mid   = read_message_id
          klass = Messages::ID_TO_KLASS.fetch(mid) do
            raise IpcProtoError, "unknown message `#{mid}`"
          end
          data  = @buf[FRAME_HDR_LEN, @len]
          @buf  = @buf[(FRAME_HDR_LEN + @len)..-1] || ""

          if @buf.bytesize >= FRAME_HDR_LEN
            @len = read_len
          else
            @len = nil
          end

          begin
            return klass.deserialize(data)
          rescue Exception => e
            # reraise protobuf decoding exceptions
            raise IpcProtoError, e.message
          end
        end
      end

      def read_sock
        ret = @sock.read_nonblock(CHUNK_SIZE)
        # Track the throughput
        @throughput.mark(ret.bytesize) if ret
        ret
      rescue Errno::EAGAIN, Errno::EWOULDBLOCK
      end

    end
  end
end
