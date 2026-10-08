import CryptoKit
import Foundation

let args = CommandLine.arguments
 guard args.count == 4,
       let signature = Data(base64Encoded: args[2]),
       let publicKey = Data(base64Encoded: args[3]) else {
    fatalError("Usage: UpdateSignatureChecks archive signature public-key")
}
let key = try Curve25519.Signing.PublicKey(rawRepresentation: publicKey)
let archive = try Data(contentsOf: URL(fileURLWithPath: args[1]))
precondition(key.isValidSignature(signature, for: archive), "Update signature does not match the app's public key")
var tampered = archive
precondition(!tampered.isEmpty)
tampered[tampered.startIndex] ^= 1
precondition(!key.isValidSignature(signature, for: tampered), "Tampered archive must be rejected")
print("Update signature verified against app public key; tampered archive rejected.")
