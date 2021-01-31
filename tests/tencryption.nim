import sysrandom
import ../src/encryption

let key = getRandomBytes(keySize).toString
let iv = getRandomBytes(ivSize).toString
let data = "this is the data"
let enc = encryptData(key, data, iv)
let dec = decryptData(key, enc, iv)
assert dec == data
