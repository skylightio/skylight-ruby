require 'openssl'

module Skylight
  module Util
    class SSL
      DEFAULT_CA_FILE  = File.expand_path('../../data/cacert.pem', __FILE__)

      def self.detect_ca_cert_file!
        return nil if ENV['SKYLIGHT_FORCE_OWN_CERTS']

        @ca_cert_file = false
        if defined?(OpenSSL::X509::DEFAULT_CERT_FILE)
          f = OpenSSL::X509::DEFAULT_CERT_FILE

          if f && File.exist?(f)
            @ca_cert_file = f
          end
        end
      end

      def self.detect_ca_cert_dir!
        return nil if ENV['SKYLIGHT_FORCE_OWN_CERTS']

        @ca_cert_dir = false
        if defined?(OpenSSL::X509::DEFAULT_CERT_DIR)
          d = OpenSSL::X509::DEFAULT_CERT_DIR

          if d && File.exist?(d)
            @ca_cert_dir = d
          end
        end
      end

      detect_ca_cert_file!
      detect_ca_cert_dir!

      def self.ca_cert_file?
        !!@ca_cert_file
      end

      def self.ca_cert_dir?
        !!@ca_cert_dir
      end

      def self.ca_cert_file_or_default
        @ca_cert_file || DEFAULT_CA_FILE
      end

      def self.ca_cert_dir
        @ca_cert_dir
      end
    end
  end
end
