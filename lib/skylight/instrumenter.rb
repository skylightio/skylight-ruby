module Skylight
  class Instrumenter < Core::Instrumenter
    def self.trace_class
      Trace
    end

    def check_install!
      # Warn if there was an error installing Skylight.

      if defined?(Skylight.check_install_errors)
        Skylight.check_install_errors(config)
      end

      if !Skylight.native? && defined?(Skylight.warn_skylight_native_missing)
        Skylight.warn_skylight_native_missing(config)
        return
      end
    end

    def process_sql(sql)
      Skylight.lex_sql(sql)
    end
  end
end
