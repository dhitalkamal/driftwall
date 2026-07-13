import Foundation

// entry point for the dependency free test runner. add new suites here as they are written.
let runner = TestRunner()

runPlaybackPolicyTests(runner)
runWallpaperConfigTests(runner)
runWallpaperControllerTests(runner)
runFeatureGateTests(runner)
runLicenseTests(runner)
runRotationTests(runner)
runPlaybackSettingsTests(runner)
runWallpaperResolverTests(runner)

exit(runner.summarize())
