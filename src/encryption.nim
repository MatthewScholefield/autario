import nimcrypto
import system

const ivSize* = 16
const keySize* = 128

proc encryptData*(key: string, data: string, iv: string): string =
  var ctx: CFB[twofish128]
  result = newString(len(data))
  ctx.init(key.toOpenArrayByte(0, key.len-1), iv.toOpenArrayByte(0, iv.len - 1))
  ctx.encrypt(data.toOpenArrayByte(0, data.len - 1), result.toOpenArrayByte(0, result.len - 1))

proc decryptData*(key: string, data: string, iv: string): string =
  var ctx: CFB[twofish128]
  result = newString(len(data))
  ctx.init(key.toOpenArrayByte(0, key.len-1), iv.toOpenArrayByte(0, iv.len - 1))
  ctx.decrypt(data.toOpenArrayByte(0, data.len - 1), result.toOpenArrayByte(0, result.len - 1))

proc toString*(bytes: openarray[byte]): string =
  result = newString(bytes.len)
  copyMem(result[0].addr, bytes[0].unsafeAddr, bytes.len)

when isMainModule:
  import sysrandom
  let iv = getRandomBytes(ivSize).toString
  let data = "this is the data"
  let enc = encryptData("secretkey", data, iv)
  let dec = decryptData("secretkey", enc, iv)
  doAssert dec == data
