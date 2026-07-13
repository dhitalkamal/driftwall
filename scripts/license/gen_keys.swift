// generate an Ed25519 issuer keypair for Driftwall licenses. run once:
//   swift scripts/license/gen_keys.swift
// embed the printed public key in Sources/DriftwallApp/Infrastructure/LicenseVerifier.swift
// and store the private key secretly (used by issue_license.swift).
import CryptoKit
import Foundation

let priv = Curve25519.Signing.PrivateKey()
print("private (keep secret): " + priv.rawRepresentation.base64EncodedString())
print("public  (embed in app): " + priv.publicKey.rawRepresentation.base64EncodedString())
