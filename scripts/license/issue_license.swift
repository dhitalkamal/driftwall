// issue a Driftwall license token. keep the private key secret (server-side / your MoR
// fulfillment webhook). usage:
//   DRIFTWALL_LICENSE_PRIVATE_KEY=<base64> swift scripts/license/issue_license.swift <email> <free|pro> [days]
// days omitted or 0 = perpetual. prints the token to paste into the app's License tab.
//
// generate a keypair once with scripts/license/gen_keys.swift, embed the public key in
// Sources/DriftwallApp/Infrastructure/LicenseVerifier.swift, and store the private key safely.
import CryptoKit
import Foundation

struct Claims: Codable {
    let email: String
    let tier: String
    let issuedAt: Date
    let expiresAt: Date?
}

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write(Data("usage: issue_license.swift <email> <free|pro> [days]\n".utf8))
    exit(2)
}
let email = args[1]
let tier = args[2]
let days = args.count >= 4 ? Int(args[3]) ?? 0 : 0

guard let privB64 = ProcessInfo.processInfo.environment["DRIFTWALL_LICENSE_PRIVATE_KEY"],
      let privData = Data(base64Encoded: privB64),
      let privateKey = try? Curve25519.Signing.PrivateKey(rawRepresentation: privData) else {
    FileHandle.standardError.write(Data("error: set DRIFTWALL_LICENSE_PRIVATE_KEY to the base64 private key\n".utf8))
    exit(1)
}

let now = Date()
let expires = days > 0 ? now.addingTimeInterval(Double(days) * 86_400) : nil
let claims = Claims(email: email, tier: tier, issuedAt: now, expiresAt: expires)

let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .iso8601
let claimsData = try encoder.encode(claims)
let signature = try privateKey.signature(for: claimsData)

let token = claimsData.base64EncodedString() + "." + signature.base64EncodedString()
print(token)
