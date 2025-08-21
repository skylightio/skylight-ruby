# frozen_string_literal: true

require "delegate"

module Skylight
  module Probes
    module DelayedJob
      begin
        require "delayed/plugin"

        UNKNOWN = "<Delayed::Job Unknown>"

        class Plugin < ::Delayed::Plugin
          callbacks do |lifecycle|
            lifecycle.around(:perform) { |worker, job, &block| sk_instrument(worker, job, &block) }
            lifecycle.after(:error) { |_worker, _job| Skylight.trace&.segment = "error" }
            lifecycle.after(:failure) { |_worker, _job| Skylight.trace&.segment = "error" }
          end

          class << self
            include Skylight::Util::Logging

            # This is called quite early in Delayed::Worker
            #
            # Typically, the `:perform` lifecycle hook is called before the
            # `payload_object` has been deserialized, so we can't name the
            # trace yet.
            #
            # If we call `payload_object` here, we would move the work of
            # loading the object ahead of where it naturally happens, which
            # means the database load time won't be instrumented. On the other
            # hand, should the deserialization fail, we would have moved the
            # timing of the error as well. Crucially – it would have moved it
            # outside of the spot where these errors are normally caught and
            # reported by the worker.
            #
            # See https://github.com/skylightio/skylight-ruby/issues/491
            def sk_instrument(_worker, job)
              Skylight.trace(
                UNKNOWN,
                "app.delayed_job.worker",
                "Delayed::Worker#run",
                component: :worker,
                segment: job.queue,
                meta: {
                  source_location: "delayed_job"
                }
              ) do
                t { "Delayed::Job beginning trace" }
                yield
              end
            end
          end
        end
      rescue LoadError
        $stderr.puts "[SKYLIGHT] The delayed_job probe was requested, but Delayed::Plugin was not defined."
      end

      def self.payload_object_name(payload_object)
        if payload_object.is_a?(::Delayed::PerformableMethod)
          payload_object.display_name
        else
          # In the case of ActiveJob-wrapped jobs, there is quite a bit of job-specific metadata
          # in `job.name`, which would break aggregation and potentially leak private data in job args.
          # Use class name instead to avoid this.
          payload_object.class.name
        end
      rescue StandardError
        UNKNOWN
      end

      def self.payload_object_source_meta(payload_object)
        if payload_object.is_a?(::Delayed::PerformableMethod)
          if payload_object.object.is_a?(Module)
            [:class_method, payload_object.object.name, payload_object.method_name.to_s]
          else
            [:instance_method, payload_object.object.class.name, payload_object.method_name.to_s]
          end
        else
          [:instance_method, payload_object.class.name, "perform"]
        end
      end

      class InstrumentationProxy < SimpleDelegator
        def perform
          if (trace = Skylight.instrumenter&.current_trace)
            if trace.endpoint == UNKNOWN
              # At this point, deserialization was, by definition, successful.
              # So it'd be safe to set the endpoint name based on the payload
              # object here.
              trace.endpoint = Skylight::Probes::DelayedJob.payload_object_name(__getobj__)
            end

            source_meta = Skylight::Probes::DelayedJob.payload_object_source_meta(__getobj__)

            opts = {
              category: "app.delayed_job.job",
              title: format_source(*source_meta),
              meta: {
                source_location_hint: source_meta
              },
              internal: true
            }

            Skylight.instrument(opts) { __getobj__.perform }
          end
        end

        # Used by Delayed::Backend::Base to determine Job#name
        def display_name
          __getobj__.respond_to?(:display_name) ? __getobj__.display_name : __getobj__.class.name
        end

        private

        def format_source(method_type, constant_name, method_name)
          method_type == :instance_method ? "#{constant_name}##{method_name}" : "#{constant_name}.#{method_name}"
        end
      end

      class Probe
        def install
          return unless validate_version && plugin_defined?

          ::Delayed::Worker.plugins = [Skylight::Probes::DelayedJob::Plugin] | ::Delayed::Worker.plugins
          ::Delayed::Backend::Base.class_eval do
            alias_method :payload_object_without_sk, :payload_object

            def payload_object
              Skylight::Probes::DelayedJob::InstrumentationProxy.new(payload_object_without_sk)
            end
          end
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
