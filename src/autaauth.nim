import oids
import times
import httpclient
import options
import sysrandom
import base64

import encryption


type AutaAuth* = object
  key*: string
  changeId*: string
  changeIdUrl*: string
  dataUrl*: string
  lastSync*: int

const correctPrefix = "1234567890"
const syncInterval = 30

proc updateSyncTime*(self: var AutaAuth) =
  self.lastSync = getTime().toUnix().int


proc simpleEncrypt(key: string, data: string): string =
  let paddedData = correctPrefix & data
  let iv = getRandomBytes(ivSize).toString
  return iv & encryptData(key, paddedData, iv)


proc simpleDecrypt(key: string, data: string): Option[string] =
  if data.len < ivSize:
    return none(string)
  let iv = data[0 .. ivSize - 1]
  let encData = data[ivSize .. data.len - 1]
  let decData = decryptData(key, encData, iv)
  if decData.len < correctPrefix.len:
    return none(string)
  let prefix = decData[0 .. correctPrefix.len - 1]
  let suffix = decData[correctPrefix.len .. decData.len - 1]
  if prefix != correctPrefix:
    return none(string)
  return some(suffix)


proc uploadData*(self: var AutaAuth, data: string) =
  self.changeId = $genOid()
  let encData = simpleEncrypt(base64.decode(self.key), data)
  var client = newHttpClient(timeout=10000)
  discard client.request(self.dataUrl, httpMethod = HttpPut, body = encData)
  client = newHttpClient(timeout=10000)
  discard client.request(self.changeIdUrl, httpMethod = HttpPut, body = self.changeId)


proc readData*(self: AutaAuth): Option[string] =
  let data = newHttpClient().getContent(self.dataUrl)
  return simpleDecrypt(base64.decode(self.key), data)


proc checkIfUpToDate*(self: var AutaAuth, forceCheck: bool = false): bool =
  let sinceSync = getTime().toUnix().int - self.lastSync
  if sinceSync < syncInterval and not forceCheck:
    return true
  if newHttpClient().getContent(self.changeIdUrl) == self.changeId:
    self.updateSyncTime()


when isMainModule:
  import strformat
  import base64
  import os

  let usage = &"Usage: {lastPathPart(getAppFilename())} encrypt|decrypt b64key b64data"

  let args = commandLineParams()

  if args.len != 3:
    echo usage
    quit(1)

  let
    key = base64.decode(args[1])
    data = base64.decode(args[2])
  
  case args[0]
  of "encrypt":
    echo base64.encode(simpleEncrypt(key, data))
  of "decrypt":
    echo base64.encode(simpleDecrypt(key, data).get)
