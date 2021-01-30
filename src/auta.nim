import os

import program
import std/exitprocs
import terminal
import strformat

import exceptions

when isMainModule:
  addExitProc(resetAttributes)
  var prog = Program()
  prog.parse(commandLineParams())
  try:
    prog.run()
  except AutaError:
    echo fmt"Error: {getCurrentExceptionMsg()}"
