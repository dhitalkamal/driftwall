import CryptoKit
import Foundation
import DriftwallCore

// verifies an offline license token signed by the issuer's Ed25519 private key. the token is
//   base64(claimsJSON) + "." + base64(signature)
// where the signature is over the exact claimsJSON bytes, so there is no re-serialization
// mismatch between issuer and app. the matching private key stays server-side (see
// scripts/license/issue_license.swift). returns the claims only if the signature is valid
// and the license is currently valid.
enum LicenseVerifier {
    // issuer public key (base64 of the 32-byte Ed25519 raw representation).
    static let publicKeyBase64 = "tk5ihq6PaNIckZ90+1Dm/7n1Uju4eBSfkZeLAhh2DdA="

    static func verify(token: String, now: Date = Date()) -> LicenseClaims? {
        let parts = token.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2,
              let claimsData = Data(base64Encoded: String(parts[0])),
              let signature = Data(base64Encoded: String(parts[1])),
              let publicKeyData = Data(base64Encoded: publicKeyBase64)
        else {
            return nil
        }

        guard let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData),
              publicKey.isValidSignature(signature, for: claimsData)
        else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let claims = try? decoder.decode(LicenseClaims.self, from: claimsData),
              claims.isCurrentlyValid(now: now)
        else {
            return nil
        }
        return claims
    }
}
