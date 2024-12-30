# Package

version       = "0.3.0"
author        = "luisacosta"
description   = "Language Handler for executing Nim inside postgres as a procedural language"
license       = "MIT"
srcDir        = "src"
#installExt    = @["nim"]
#bin           = @["plnim"]


# Dependencies

requires "nim >= 2.0", "pgxcrown >= 0.7.0"

# Compile plnim extension library
before install:
    exec("echo - Building PL/Nim extension library")
    exec("echo - Loading PL/Nim extension library") 
    exec("touch $HOME/pgfunctions.nim")   
    #exec("""nim c --hints:off -d:release --app:lib -o:libplnim.so src/plnim && sudo mv libplnim.so $(pg_config --pkglibdir)""")
    exec("""nim c --hints:off -d:release --app:lib -o:libplnim.so src/plnim""")
