import Foundation
import DriftwallCore

func runLicenseTests(_ t: TestRunner) {
    let now = Date(timeIntervalSince1970: 1_000_000)

    // a perpetual license (no expiry) is always valid and grants pro.
    let perpetual = LicenseClaims(
        email: "a@b.com", tier: .pro, issuedAt: now, expiresAt: nil
    )
    t.expect(perpetual.isCurrentlyValid(now: now), "perpetual license should be valid")
    t.expect(
        perpetual.isCurrentlyValid(now: now.addingTimeInterval(10_000_000_000)),
        "perpetual license should not expire"
    )
    t.expectEqual(perpetual.tier, .pro)

    // a not-yet-expired license is valid.
    let future = LicenseClaims(
        email: "a@b.com", tier: .pro, issuedAt: now, expiresAt: now.addingTimeInterval(1000)
    )
    t.expect(future.isCurrentlyValid(now: now), "unexpired license should be valid")

    // an expired license is invalid.
    let expired = LicenseClaims(
        email: "a@b.com", tier: .pro, issuedAt: now, expiresAt: now.addingTimeInterval(-1)
    )
    t.expect(expired.isCurrentlyValid(now: now) == false, "expired license should be invalid")

    // claims round-trip through json so a license file can be stored and reloaded.
    do {
        let data = try JSONEncoder().encode(future)
        let decoded = try JSONDecoder().decode(LicenseClaims.self, from: data)
        t.expectEqual(decoded, future)
    } catch {
        t.expect(false, "license claims failed to round-trip: \(error)")
    }
}
