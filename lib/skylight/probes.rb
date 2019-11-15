require "pathname"

module Skylight
  # @api private
  module Probes
    class ProbeRegistration
      attr_reader :name, :klass_name, :require_paths, :probe

      def initialize(name, klass_name, require_paths, probe)
        @name = name
        @klass_name = klass_name
        @require_paths = Array(require_paths)
        @probe = probe
      end

      def install
        probe.install
      end
    end

    class << self
      def paths
        @paths ||= []
      end

      def add_path(path)
        root = Pathname.new(path)
        Pathname.glob(root.join("./**/*.rb")).each do |f|
          name = f.relative_path_from(root).sub_ext("").to_s
          if available.key?(name)
            raise "duplicate probe name: #{name}; original=#{available[name]}; new=#{f}"
          end

          available[name] = f
        end
      end

      def available
        @available ||= {}
      end

      def probe(*probes)
        unknown = probes.map(&:to_s) - available.keys
        unless unknown.empty?
          raise ArgumentError, "unknown probes: #{unknown.join(', ')}"
        end

        probes.each do |p|
          require available[p.to_s]
        end
      end

      def require_hooks
        @require_hooks ||= {}
      end

      def installed
        @installed ||= {}
      end

      def available?(klass_name)
        !!::ActiveSupport::Inflector.safe_constantize(klass_name)
      end

      def register(name, *args)
        registration = ProbeRegistration.new(name, *args)

        if available?(registration.klass_name)
          installed[registration.klass_name] = registration
          registration.install
        else
          register_require_hook(registration)
        end
      end

      def require_hook(require_path)
        registration = lookup_by_require_path(require_path)
        return unless registration

        # Double check constant is available
        if available?(registration.klass_name)
          installed[registration.klass_name] = registration
          registration.install

          # Don't need this to be called again
          unregister_require_hook(registration)
        end
      end

      def register_require_hook(registration)
        registration.require_paths.each do |p|
          require_hooks[p] = registration
        end
      end

      def unregister_require_hook(registration)
        registration.require_paths.each do |p|
          require_hooks.delete(p)
        end
      end

      def lookup_by_require_path(require_path)
        require_hooks[require_path]
      end
    end

    add_path(File.expand_path("./probes", __dir__))
  end
end

# Allow hooking require
# @api private
module ::Kernel
  private

    alias require_without_sk require

    def require(name)
      ret = require_without_sk(name)

      begin
        Skylight::Probes.require_hook(name)
      rescue Exception # rubocop:disable Lint/HandleExceptions
        # FIXME: Log these errors
      end

      ret
    end
end
