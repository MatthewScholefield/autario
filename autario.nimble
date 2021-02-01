# Package

version       = "0.5.0"
author        = "Matthew D. Scholefield"
description   = "A command line tool to automate your life"
license       = "MIT"
srcDir        = "src"
bin           = @["auta"]



# Dependencies

requires "nim >= 1.0.2"
requires "https://github.com/MatthewScholefield/appdirs >= 0.1.2"
requires "nimcrypto"
requires "sysrandom"
