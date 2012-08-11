require 'mkmf'

abort "libuuid not found"    unless have_library('uuid')
abort "libpthread not found" unless have_library('pthread')

CONFIG['warnflags'].gsub!('-Wdeclaration-after-statement',   '')
CONFIG['warnflags'].gsub!('-Wimplicit-function-declaration', '')

create_makefile 'direwolf_native/direwolf_native'
