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
    rescue SqlLexError => e
      if config[:log_sql_parse_errors]
        config.logger.error "[#{e.formatted_code}] Failed to extract binds from SQL query. " \
                            "It's likely that this query uses more advanced syntax than we currently support. " \
                            "sql=#{sql.inspect}"
      end
      nil
    end

    def handle_instrumenter_error(trace, e)
      poison! if e.is_a?(Skylight::InstrumenterUnrecoverableError)
      super
    end
  end
end
