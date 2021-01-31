import macros
import os
import strutils

macro debug*(n: varargs[typed]): untyped =
  result = newNimNode(nnkStmtList, n)
  for i in 0..n.len-1:
    if n[i].kind == nnkStrLit:
      # pure string literals are written directly
      result.add(newCall("write", newIdentNode("stdout"), n[i]))
    else:
      # other expressions are written in <expression>: <value> syntax
      result.add(newCall("write", newIdentNode("stdout"), toStrLit(n[i])))
      result.add(newCall("write", newIdentNode("stdout"), newStrLitNode(": ")))
      result.add(newCall("write", newIdentNode("stdout"), n[i]))
    if i != n.len-1:
      # separate by ", "
      result.add(newCall("write", newIdentNode("stdout"), newStrLitNode(", ")))
    else:
      # add newline
      result.add(newCall("writeLine", newIdentNode("stdout"), newStrLitNode("")))

proc ensureParent*(path: string) =
  let parent = parentDir(path)
  if not dirExists(parent):
    ensureParent(parent)
    createDir(parent)

proc getExceptionDetail*(): string =
  result = getCurrentExceptionMsg()
  if result.contains("Additional info: "):
    result = result.split("Additional info: ")[1]
  result = result.replace('\n', ' ').strip(chars={' ', '"'})
