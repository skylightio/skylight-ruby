# frozen_string_literal: true

module Skylight
  module Probes
    module DelayedJob
      begin
        require 'delayed/plugin'

        class Plugin < ::Delayed::Plugin
          UNKNOWN = "<Delayed::Job Unknown>".freeze

          callbacks do |lifecycle|
            lifecycle.around(:perform) do |worker, job, &block|
              sk_instrument(worker, job, &block)
            end

            lifecycle.after(:error) do |_worker, _job|
              Skylight.trace&.segment = "error"
            end

            # FIXME: this block *still* includes payload_object deserialization time (lazy, triggered by `hook :before`)
            # we only want to instrumet #perform.
            #
            # see lib/delayed/backend/base.rb:81
            # - could wrap payload_object in a proxy?
            # - override invoke_job?
            lifecycle.around(:invoke_job) do |*args, &block|
              block.call
            end
          end

          class << self
            include Skylight::Util::Logging

            def sk_instrument(worker, job)
              endpoint = handler_name(job)

              Skylight.trace(handler_name(job),
                             "app.delayed_job.worker",
                             "Delayed::Worker#run",
                             component: :worker,
                             segment: job.queue) do
                               t { "Delayed::Job beginning trace" }
                               yield
                             end
            end

            def handler_name(job)
              if defined?(::Delayed::PerformableMethod) && job.payload_object.is_a?(::Delayed::PerformableMethod)
                job.name
              else
                job.payload_object.class.name
              end
            rescue
              UNKNOWN
            end
          end
        end
      rescue LoadError
        $stderr.puts "[SKYLIGHT] The delayed_job probe was requested, but Delayed::Plugin was not defined."
      end

      class Probe
        def install
          return unless validate_version && plugin_defined?

          ::Delayed::Worker.plugins = [Skylight::Probes::DelayedJob::Plugin] | ::Delayed::Worker.plugins
        end

        private

          def plugin_defined?
            defined?(::Skylight::Probes::DelayedJob::Plugin)
          end

          def validate_version
            spec = Gem.loaded_specs["delayed_job"]
            version = spec&.version

            if !version || version < Gem::Version.new("4.0.0")
              Skylight.error "The installed version of DelayedJob is not supported on Skylight. " \
                             "Your jobs will not be tracked."

              return false
            end

            true
          end
      end
    end

    register(:delayed_job, "Delayed::Worker", "delayed_job", DelayedJob::Probe.new)
  end
end
