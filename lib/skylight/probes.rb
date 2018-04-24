require 'pathname'

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

    def self.available
      unless @available
        root = Pathname.new(File.expand_path("../probes", __FILE__))
        @available = {}
        Dir["#{root}/**/*.rb"].each do |f|
          name = Pathname.new(f).relative_path_from(root).sub_ext('').to_s
          @available[name] = "skylight/probes/#{name}"
        end
      end
      @available
    end

    def self.probe(*probes)
      unknown = probes.map(&:to_s) - available.keys
      unless unknown.empty?
        raise ArgumentError, "unknown probes: #{unknown.join(', ')}"
      end

      probes.each do |p|
        begin
          @via_api = true
          require available[p.to_s]
        ensure
          @via_api = false
        end
      end
    end

    def self.require_hooks
      @require_hooks ||= {}
    end

    def self.installed
      @installed ||= {}
    end

    def self.is_available?(klass_name)
      !!Skylight::Util::Inflector.safe_constantize(klass_name)
    end

    def self.register(name, *args)
      unless @via_api
        DEPRECATOR.deprecation_warning("Enabling probes via `require` alone",
                                        "use `Skylight.probe(:#{name})` instead")
      end

      registration = ProbeRegistration.new(name, *args)

      if is_available?(registration.klass_name)
        installed[registration.klass_name] = registration
        registration.install
      else
        register_require_hook(registration)
      end
    end

    def self.require_hook(require_path)
      return unless Skylight.native?

      registration = lookup_by_require_path(require_path)
      return unless registration

      # Double check constant is available
      if is_available?(registration.klass_name)
        installed[registration.klass_name] = registration
        registration.install

        # Don't need this to be called again
        unregister_require_hook(registration)
      end
    end

    def self.register_require_hook(registration)
      registration.require_paths.each do |p|
        require_hooks[p] = registration
      end
    end

    def self.unregister_require_hook(registration)
      registration.require_paths.each do |p|
        require_hooks.delete(p)
      end
    end

    def self.lookup_by_require_path(require_path)
      require_hooks[require_path]
    end
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
    rescue Exception
      # FIXME: Log these errors
    end

    ret
  end
end
