require "pathname"

module Skylight
  # @api private
  module Probes
    class ProbeRegistration
      attr_reader :name, :const_name, :require_paths, :probe

      def initialize(name, const_name, require_paths, probe)
        @name = name
        @const_name = const_name
        @require_paths = Array(require_paths)
        @probe = probe
      end

      def install
        probe.install
      end

      def constant_available?
        ::ActiveSupport::Inflector.safe_constantize(const_name).present?
      end
    end

    class << self
      def install!
        pending = registered.values - installed.values

        pending.each do |registration|
          if registration.constant_available?
            install_probe(registration)
          else
            register_require_hook(registration)
          end
        end
      end

      def install_probe(registration)
        return if installed.key?(registration.name)

        installed[registration.name] = registration
        registration.install
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

      def registered
        @registered ||= {}
      end

      def require_hooks
        @require_hooks ||= {}
      end

      def installed
        @installed ||= {}
      end

      def register(name, *args)
        if registered.key?(name)
          raise "already registered: #{name}"
        end

        registered[name] = ProbeRegistration.new(name, *args)

        true
      end

      def require_hook(require_path)
        registration = lookup_by_require_path(require_path)
        return unless registration

        # Double check constant is available
        if registration.constant_available?
          install_probe(registration)

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

# @api private
module Kernel
  # Unfortunately, we can't use prepend here, in part because RubyGems changes require with an alias
  alias require_without_sk require

  def require(name)
    require_without_sk(name).tap do
      begin
        Skylight::Probes.require_hook(name)
      rescue Exception # rubocop:disable Lint/SuppressedException
        # FIXME: Log these errors
      end
    end
  end
end
