import DriftwallCore

func runFeatureGateTests(_ t: TestRunner) {
    // free tier unlocks none of the pro features.
    for feature in ProFeature.allCases {
        t.expect(
            FeatureGate.isAllowed(feature, tier: .free) == false,
            "free tier should not allow \(feature)"
        )
    }

    // pro tier unlocks every pro feature.
    for feature in ProFeature.allCases {
        t.expect(
            FeatureGate.isAllowed(feature, tier: .pro),
            "pro tier should allow \(feature)"
        )
    }
}
