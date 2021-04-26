module Skylight
  module Probes
    module ActiveModelSerializers
      module Instrumentation
        def as_json(*)
          payload = { serializer: self.class }
          ActiveSupport::Notifications.instrument("render.active_model_serializers", payload) { super }
        end
      end

      class Probe
        def install
          version = nil

          # File moved location between version
          %w[serializer serializers].each do |dir|
            require "active_model/#{dir}/version"
          rescue LoadError # rubocop:disable Lint/SuppressedException
          end

          version = Gem.loaded_specs["active_model_serializers"].version if Gem.loaded_specs["active_model_serializers"]

          if !version || version < Gem::Version.new("0.5.0")
            Skylight.error "Instrumention is only available for ActiveModelSerializers version 0.5.0 and greater."
            return
          end

          # We don't actually support the RCs correctly, requires
          # a release after 0.10.0.rc3
          if version >= Gem::Version.new("0.10.0.rc1")
            # AS::N is built in to newer versions
            return
          end

          # End users could override as_json without calling super, but it's likely safer
          # than overriding serializable_array/hash/object.

          [::ActiveModel::Serializer, ::ActiveModel::ArraySerializer].each { |klass| klass.prepend(Instrumentation) }
        end
      end
    end

    register(
      :active_model_serializers,
      "ActiveModel::Serializer",
      "active_model/serializer",
      ActiveModelSerializers::Probe.new
    )
  end
end
