module Skylight
  module Probes
    module Redis
      # Unfortunately, because of the nature of pipelining, there's no way for us to
      # give a time breakdown on the individual items.

      PIPELINED_OPTS = { category: "db.redis.pipelined".freeze, title: "PIPELINE".freeze, internal: true }.freeze

      MULTI_OPTS = { category: "db.redis.multi".freeze, title: "MULTI".freeze, internal: true }.freeze

      CONNECT_OPTS = { category: "db.redis.connect".freeze, title: "CONNECT".freeze, internal: true }.freeze

      # redis < 5
      module ClientInstrumentation
        def call(command, *)
          command_name = command[0]

          return super if command_name == :auth

          opts = { category: "db.redis.command", title: command_name.upcase.to_s, internal: true }

          Skylight.instrument(opts) { super }
        end
      end

      module Instrumentation
        def pipelined(*)
          Skylight.instrument(PIPELINED_OPTS) { super }
        end

        def multi(*)
          Skylight.instrument(MULTI_OPTS) { super }
        end
      end

      class Probe
        def install
          # A `Redis` namespace from something other than the redis gem; nothing to patch.
          # (redis-client, if present, is installed by its own registration below.)
          return unless defined?(::Redis::Client)

          # redis 5+ is built on redis-client, which is instrumented below. Patching Redis
          # as well would record each command twice.
          if defined?(::RedisClient) && ::Redis::Client < ::RedisClient
            Skylight::Probes.install_probe(Skylight::Probes.registered.fetch(:redis_client))
            return
          end

          version = defined?(::Redis::VERSION) ? Gem::Version.new(::Redis::VERSION) : nil

          if !version || version < Gem::Version.new("3.0.0")
            Skylight.error "The installed version of Redis doesn't support Middlewares. " \
                             "At least version 3.0.0 is required."
            return
          end

          ::Redis::Client.prepend(ClientInstrumentation)
          ::Redis.prepend(Instrumentation)
        end
      end

      # redis-client is used directly by e.g. Sidekiq 7+, and by redis 5+ under the hood.
      module RedisClient
        # Registered globally, so this applies to every RedisClient instance.
        module Middleware
          def call(command, _config)
            command_name = command[0].to_s

            return super if command_name.casecmp?("auth")

            opts = { category: "db.redis.command", title: command_name.upcase, internal: true }

            Skylight.instrument(opts) { super }
          end

          def call_pipelined(commands, _config)
            # Transactions are sent as a pipeline wrapped in MULTI ... EXEC
            opts = commands.dig(0, 0).to_s.casecmp?("multi") ? MULTI_OPTS : PIPELINED_OPTS

            Skylight.instrument(opts) { super }
          end
        end

        # Covers the whole connection setup: the socket (and TLS) connect, plus the handshake
        # (HELLO/AUTH/SELECT, etc.). The handshake goes through the middleware as an ordinary
        # pipeline, with nothing to tell it apart from the user's, so it's muted here.
        # `connect` is private, so accept any arguments in case its signature changes.
        module ConnectInstrumentation
          private

          def connect(*, **)
            Skylight.instrument(CONNECT_OPTS) { Skylight.mute { super } }
          end
        end

        class Probe
          def install
            ::RedisClient.register(Middleware)
            ::RedisClient.prepend(ConnectInstrumentation)
          end
        end
      end
    end

    # A single `redis` probe covers both gems: redis-client is often used without redis
    # (e.g. by Sidekiq 7+), and either may be loaded first.
    register(:redis, "Redis", "redis", Redis::Probe.new)
    register(:redis_client, "RedisClient", %w[redis-client redis_client], Redis::RedisClient::Probe.new)
  end
end
