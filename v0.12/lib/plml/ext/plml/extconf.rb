require 'mkmf'

#find_library("plrt", "plMTInit", "/usr/lib")
#abort "pl-rt is missing!" unless have_library("plrt", "plMLParse", "plrt-plml.h")

CONFIG["optflags"] = "-O0"
CONFIG["debugflags"] = "-g"
$LDFLAGS = "-lplrt"

create_makefile "plml/plml"
