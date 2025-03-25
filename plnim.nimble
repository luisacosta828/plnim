# Package

version       = "0.3.1"
author        = "luisacosta"
description   = "Language Handler for executing Nim inside postgres as a procedural language"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 2.0", "pgxcrown >= 0.9.0"

# Compile plnim extension library
before install:
    exec("""nim c --hints:off -d:release --app:lib -o:plnim.so src/plnim""")
