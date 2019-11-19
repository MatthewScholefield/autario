import os

import program
import system
import terminal

when isMainModule:
  system.addQuitProc(resetAttributes)
  var prog = Program()
  prog.parse(commandLineParams())
  prog.run()
