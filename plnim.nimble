    # Package

version       = "0.8.0"
author        = "luisacosta"
description   = "Language Handler for executing Nim inside postgres as a procedural language"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 2.0", "pgxcrown >= 0.21.0"

# Compile plnim extension library
before install:
    let pgInc = staticExec("pg_config --includedir-server")
    exec("nim c --hints:off -d:release --app:lib --cincludes:\"" & pgInc & "\" -o:plnim.so src/plnim")
