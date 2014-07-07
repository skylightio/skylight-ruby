module Skylight
  module Probes
    module Redis
      class Probe
        def install
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
      end
    end

    register("Redis", "redis", Redis::Probe.new)
  end
end
