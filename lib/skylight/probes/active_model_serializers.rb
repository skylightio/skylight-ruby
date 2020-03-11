module Skylight
  module Probes
    module ActiveModelSerializers
      class Probe
        def install
          version = nil

          # File moved location between version
          %w[serializer serializers].each do |dir|
            # rubocop:disable Lint/SuppressedException
            begin
              require "active_model/#{dir}/version"
            rescue LoadError
            end
            # rubocop:enable Lint/SuppressedException
          end

          if Gem.loaded_specs["active_model_serializers"]
            version = Gem.loaded_specs["active_model_serializers"].version
          end

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

          [::ActiveModel::Serializer, ::ActiveModel::ArraySerializer].each do |klass|
            klass.class_eval do
              alias_method :as_json_without_sk, :as_json
              def as_json(*args)
                payload = { serializer: self.class }
                ActiveSupport::Notifications.instrument("render.active_model_serializers", payload) do
                  as_json_without_sk(*args)
                end
              end
            end
          end
        end
      end
    end

    register(:active_model_serializers, "ActiveModel::Serializer", "active_model/serializer",
             ActiveModelSerializers::Probe.new)
  end
end
