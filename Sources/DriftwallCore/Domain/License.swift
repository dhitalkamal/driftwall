import Foundation

// which tier of the app is unlocked.
public enum LicenseTier: String, Codable, Sendable {
    case free
    case pro
}

// features that require a pro license. free tier gets none of these.
public enum ProFeature: String, Sendable, CaseIterable {
    case perDisplayVideo
    case playlists
    case playbackFX
    case lockScreen
}

// the single place that decides free vs pro capability.
public enum FeatureGate {
    public static func isAllowed(_ feature: ProFeature, tier: LicenseTier) -> Bool {
        switch tier {
        case .free:
            return false
        case .pro:
            return true
        }
    }
}

// the claims carried by a license. these are signed by the issuer (server-side private key)
// and verified in the app layer with the embedded public key; this type holds the data and
// the pure validity rules. expiresAt == nil means a perpetual license.
public struct LicenseClaims: Codable, Equatable, Sendable {
    public let email: String
    public let tier: LicenseTier
    public let issuedAt: Date
    public let expiresAt: Date?

    public init(email: String, tier: LicenseTier, issuedAt: Date, expiresAt: Date?) {
        self.email = email
        self.tier = tier
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
    }

    public func isCurrentlyValid(now: Date) -> Bool {
        guard let expiresAt else { return true }
        return now < expiresAt
    }
}
