import nimcrypto

proc encryptData*(key: string, data: string, iv: string): string =
  var ctx: CFB[blowfish]
  result = newString(len(data))
  ctx.cipher.init(key.toOpenArrayByte(0, key.len-1))
  copyMem(addr ctx.iv[0], unsafeAddr iv[0], ctx.sizeBlock)
  ctx.encrypt(data.toOpenArrayByte(0, data.len - 1), result.toOpenArrayByte(0, result.len - 1))

proc decryptData*(key: string, data: string, iv: string): string =
  var ctx: CFB[blowfish]
  result = newString(len(data))
  ctx.cipher.init(key.toOpenArrayByte(0, key.len-1))
  copyMem(addr ctx.iv[0], unsafeAddr iv[0], ctx.sizeBlock)
  ctx.decrypt(data.toOpenArrayByte(0, data.len - 1), result.toOpenArrayByte(0, result.len - 1))
