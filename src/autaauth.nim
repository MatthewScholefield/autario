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

proc uploadData*(self: var AutaAuth, data: string) =
  self.changeId = $genOid()
  let paddedData = correctPrefix & data
  let iv = getRandomBytes(ivSize).toString
  let encData = iv & encryptData(decode(self.key), paddedData, iv)
  var client = newHttpClient(timeout=10000)
  discard client.request(self.dataUrl, httpMethod = HttpPut, body = encData)
  client = newHttpClient(timeout=10000)
  discard client.request(self.changeIdUrl, httpMethod = HttpPut, body = self.changeId)

proc readData*(self: AutaAuth): Option[string] =
  let data = newHttpClient().getContent(self.dataUrl)
  if data.len < ivSize:
    return none(string)
  let iv = data[0 .. ivSize - 1]
  let encData = data[ivSize .. data.len - 1]
  let decData = decryptData(decode(self.key), encData, iv)
  if decData.len < correctPrefix.len:
    return none(string)
  let prefix = decData[0 .. correctPrefix.len - 1]
  let suffix = decData[correctPrefix.len .. decData.len - 1]
  if prefix != correctPrefix:
    return none(string)
  return some(suffix)

proc checkIfUpToDate*(self: var AutaAuth, forceCheck: bool = false): bool =
  let sinceSync = getTime().toUnix().int - self.lastSync
  if sinceSync < syncInterval and not forceCheck:
    return true
  if newHttpClient().getContent(self.changeIdUrl) == self.changeId:
    self.updateSyncTime()
    return true
