require 'thread'

module Skylight
  module Worker
    class ConnectionSet
      attr_reader :open_connections, :throughput

      def initialize
        @connections = {}
        @lock = Mutex.new

        # Metrics
        @open_connections = build_open_connections_metric
        @throughput = build_throughput_metric
      end

      def add(sock)
        conn = Connection.new(sock)
        @lock.synchronize { @connections[sock] = conn }
        conn
      end

      def socks
        @lock.synchronize { @connections.keys }
      end

      def [](sock)
        @lock.synchronize do
          @connections[sock]
        end
      end

      def cleanup(sock)
        if conn = @lock.synchronize { @connections.delete(sock) }
          conn.cleanup
          sock.close rescue nil
        end
      end

    private

      def build_open_connections_metric
        lambda do
          @lock.synchronize { @connections.length }
        end
      end

      def build_throughput_metric
        lambda do
          conns = @lock.synchronize { @connections.values }
          conns.map { |c| c.throughput.rate.to_i }
        end
      end
    end
  end
end
