import Foundation

// entry point for the dependency free test runner. add new suites here as they are written.
let runner = TestRunner()

runPlaybackPolicyTests(runner)
runWallpaperConfigTests(runner)
runWallpaperControllerTests(runner)
runRotationTests(runner)
runPlaybackSettingsTests(runner)
runWallpaperResolverTests(runner)
runFullscreenDetectorTests(runner)
runFullscreenPlaybackTests(runner)
runVideoDetailsTests(runner)
runPickWinsTests(runner)
runVideoFileTypesTests(runner)

exit(runner.summarize())
