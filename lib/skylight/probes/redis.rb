module Skylight
  module Probes
    module Redis
      class Probe
        def install
          version = defined?(::Redis::VERSION) ? Gem::Version.new(::Redis::VERSION) : nil

          if !version || version < Gem::Version.new("3.0.0")
            # Using $stderr here isn't great, but we don't have a logger accessible
            $stderr.puts "[SKYLIGHT] [#{Skylight::VERSION}] The installed version of Redis doesn't " \
                          "support Middlewares. At least version 3.0.0 is required."
            return
          end

          ::Redis::Client.class_eval do
            alias call_without_sk call

            def call(command, &block)
              command_name = command[0]

              return call_without_sk(command, &block) if command_name == :auth

              opts = {
                category: "db.redis.command",
                title:    command_name.upcase.to_s
              }

              Skylight.instrument(opts) do
                call_without_sk(command, &block)
              end
            end
          end
        end

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

        ::Redis.class_eval do
          alias pipelined_without_sk pipelined

          def pipelined(&block)
            Skylight.instrument(PIPELINED_OPTS) do
              pipelined_without_sk(&block)
            end
          end


          alias multi_without_sk multi

          def multi(&block)
            Skylight.instrument(MULTI_OPTS) do
              multi_without_sk(&block)
            end
          end
        end
      end
    end

    register("Redis", "redis", Redis::Probe.new)
  end
end
