require "openssl"

module Skylight
  module Util
    class SSL
      DEFAULT_CA_FILE = File.expand_path("../data/cacert.pem", __dir__)

      def self.detect_ca_cert_file!
        return nil if ENV["SKYLIGHT_FORCE_OWN_CERTS"]

        @ca_cert_file = false
        if defined?(OpenSSL::X509::DEFAULT_CERT_FILE)
          f = OpenSSL::X509::DEFAULT_CERT_FILE

          @ca_cert_file = f if f && File.exist?(f)
        end
      end

      detect_ca_cert_file!

      def self.ca_cert_file?
        !!@ca_cert_file
      end

      def self.ca_cert_file_or_default
        @ca_cert_file || DEFAULT_CA_FILE
      end
    end
  end
end
