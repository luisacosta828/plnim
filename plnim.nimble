# Package

version       = "0.1.0"
author        = "luisacosta"
description   = "Language Handler for executing Nim inside postgres as a procedural language"
license       = "MIT"
srcDir        = "src"
#installExt    = @["nim"]
#bin           = @["plnim"]


# Dependencies

requires "nim >= 0.19.4", "pgxcrown >= 0.4.2"

