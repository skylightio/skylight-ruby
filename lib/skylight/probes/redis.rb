module Skylight
  module Probes
    module Redis
      # Unfortunately, because of the nature of pipelining, there's no way for us to
      # give a time breakdown on the individual items.

      PIPELINED_OPTS = {
        category: "db.redis.pipelined".freeze,
        title:    "PIPELINE".freeze
      }.freeze

      MULTI_OPTS = {
        category: "db.redis.multi".freeze,
        title:    "MULTI".freeze
      }.freeze

      module ClientInstrumentation
        def call(command, *)
          command_name = command[0]

          return super if command_name == :auth

          opts = {
            category: "db.redis.command",
            title:    command_name.upcase.to_s
          }

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
    end

    register(:redis, "Redis", "redis", Redis::Probe.new)
  end
end
