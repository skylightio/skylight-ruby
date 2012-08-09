require 'mkmf'

unless have_library('uuid')
  abort "libuuid not found"
end

CONFIG['warnflags'].gsub!('-Wdeclaration-after-statement',   '')
CONFIG['warnflags'].gsub!('-Wimplicit-function-declaration', '')

create_makefile 'direwolf_native/direwolf_native'
