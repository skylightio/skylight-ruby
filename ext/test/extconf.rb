require 'mkmf'

have_header 'dlfcn.h'

find_header("rust_support/ruby.h", "..") || abort("No rust_support")
find_library("skylight_test", "skylight_test_factory", ".") || abort("No skylight_test")

$CFLAGS << " -Werror"
if RbConfig::CONFIG["arch"] =~ /darwin(\d+)?/
  $LDFLAGS << " -lpthread"
else
  $LDFLAGS << " -Wl"
  $LDFLAGS << " -lrt -ldl -lm -lpthread"
end

CONFIG['warnflags'].gsub!('-Wdeclaration-after-statement', '')

create_makefile 'skylight_native_test', '.'
