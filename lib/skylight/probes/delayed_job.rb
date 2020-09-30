# frozen_string_literal: true

require "delegate"

module Skylight
  module Probes
    module DelayedJob
      begin
        require "delayed/plugin"

        class Plugin < ::Delayed::Plugin
          callbacks do |lifecycle|
            lifecycle.around(:perform) do |worker, job, &block|
              sk_instrument(worker, job, &block)
            end

            lifecycle.after(:error) do |_worker, _job|
              Skylight.trace&.segment = "error"
            end
          end

          class << self
            include Skylight::Util::Logging

            def sk_instrument(_worker, job)
              endpoint = Skylight::Probes::DelayedJob.handler_name(job)

              Skylight.trace(endpoint,
                             "app.delayed_job.worker",
                             "Delayed::Worker#run",
                             component: :worker,
                             segment:   job.queue,
                             meta:      { source_location: "delayed_job" }) do
                               t { "Delayed::Job beginning trace" }
                               yield
                             end
            end
          end
        end
      rescue LoadError
        $stderr.puts "[SKYLIGHT] The delayed_job probe was requested, but Delayed::Plugin was not defined."
      end

      UNKNOWN = "<Delayed::Job Unknown>"

      def self.handler_name(job)
        payload_object = if job.respond_to?(:payload_object_without_sk)
                           job.payload_object_without_sk
                         else
                           job.payload_object
                         end

        payload_object_name(payload_object)
      end

      def self.format_handler_source(method_type, constant_name, method_name)
        case method_type
        when :instance_method
          "#{constant_name}##{method_name}"
        else
          "#{constant_name}.#{method_name}"
        end
      end

      def self.payload_object_name(payload_object)
        if payload_object.is_a?(::Delayed::PerformableMethod)
          payload_object.display_name
        else
          # In the case of ActiveJob-wrapped jobs, there is quite a bit of job-specific metadata
          # in `job.name`, which would break aggregation.
          payload_object.class.name
        end
      rescue
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
          source_meta = Skylight::Probes::DelayedJob.payload_object_source_meta(__getobj__)

          opts = {
            category: "app.delayed_job.job",
            title:    format_source(*source_meta),
            meta:     { source_location_hint: source_meta }
          }

          Skylight.instrument(opts) { __getobj__.perform }
        end

        # Used by Delayed::Backend::Base to determine Job#name
        def display_name
          __getobj__.respond_to?(:display_name) ? __getobj__.display_name : __getobj__.class.name
        end

        private

          def sk_span_title
            Skylight::Probes::DelayedJob.payload_object_name(__getobj__)
          end

          def format_source(method_type, constant_name, method_name)
            case method_type
            when :instance_method
              "#{constant_name}##{method_name}"
            else
              "#{constant_name}.#{method_name}"
            end
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
