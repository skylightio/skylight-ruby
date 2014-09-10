require 'rbconfig'

# Used from extconf and to load libskylight
module Skylight
  module Util
    module Platform
      # Normalize the platform OS
      OS = case os = RbConfig::CONFIG['host_os'].downcase
      when /linux/
        "linux"
      when /darwin/
        "darwin"
      when /freebsd/
        "freebsd"
      when /netbsd/
        "netbsd"
      when /openbsd/
        "openbsd"
      when /sunos|solaris/
        "solaris"
      when /mingw|mswin/
        "windows"
      else
        os
      end

      # Normalize the platform CPU
      ARCH = case cpu = RbConfig::CONFIG['host_cpu'].downcase
      when /amd64|x86_64/
        "x86_64"
      when /i?86|x86|i86pc/
        "i386"
      when /ppc|powerpc/
        "powerpc"
      when /^arm/
        "arm"
      else
        cpu
      end

      LIBEXT = case OS
      when /darwin/
        'dylib'
      when /linux|bsd|solaris/
        'so'
      when /windows|cygwin/
        'dll'
      else
        'so'
      end

      TUPLE = "#{ARCH}-#{OS}"

      def self.tuple
        TUPLE
      end

      def self.libext
        LIBEXT
      end

      def self.dlext
        RbConfig::CONFIG['DLEXT']
      end
    end
  end
end
