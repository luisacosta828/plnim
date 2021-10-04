# Package

version       = "0.2.0"
author        = "luisacosta"
description   = "Language Handler for executing Nim inside postgres as a procedural language"
license       = "MIT"
srcDir        = "src"
#installExt    = @["nim"]
#bin           = @["plnim"]


# Dependencies

requires "nim >= 0.19.4", "pgxcrown >= 0.4.2"

# Compile plnim extension library
before install:
    exec("echo - Building PL/Nim extension library")
    exec("echo - Loading PL/Nim extension library") 
    exec("touch $HOME/pgfunctions.nim")   
    exec("""nim c --hints:off -d:release --app:lib -o:libplnim.so src/plnim && sudo mv libplnim.so $(pg_config --pkglibdir)""")
