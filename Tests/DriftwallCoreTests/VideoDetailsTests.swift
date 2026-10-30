import DriftwallCore

func runVideoDetailsTests(_ t: TestRunner) {
    // everything known: resolution, short loop, size in MB.
    let full = VideoDetails(pixelWidth: 3840, pixelHeight: 2160, durationSeconds: 42.4, byteCount: 186_000_000)
    t.expectEqual(full.summary, "3840 x 2160, 42 s loop, 186 MB")
    t.expectEqual(full.loopLength, "0:42")

    // a minute or longer reads as minutes and seconds, in both places.
    let long = VideoDetails(pixelWidth: 1920, pixelHeight: 1080, durationSeconds: 70, byteCount: 2_450_000_000)
    t.expectEqual(long.summary, "1920 x 1080, 1:10 loop, 2.5 GB")
    t.expectEqual(long.loopLength, "1:10")

    // an hour or longer gains an hours field.
    let hour = VideoDetails(durationSeconds: 3723)
    t.expectEqual(hour.summary, "1:02:03 loop")
    t.expectEqual(hour.loopLength, "1:02:03")

    // rounding to the nearest second can roll a sub-minute loop over to 1:00.
    let almost = VideoDetails(durationSeconds: 59.6)
    t.expectEqual(almost.summary, "1:00 loop")
    t.expectEqual(almost.loopLength, "1:00")

    // small files use KB; sub-1 KB still says something useful.
    t.expectEqual(VideoDetails(byteCount: 640_000).summary, "640 KB")
    t.expectEqual(VideoDetails(byteCount: 300).summary, "1 KB")

    // missing parts are left out instead of showing placeholders.
    t.expectEqual(VideoDetails(pixelWidth: 1280, pixelHeight: 720).summary, "1280 x 720")
    t.expectEqual(VideoDetails(pixelWidth: 1280).summary, "")
    t.expectEqual(VideoDetails().summary, "")
    t.expectEqual(VideoDetails().loopLength, nil)

    // zero, negative, or non-finite durations are treated as unknown.
    t.expectEqual(VideoDetails(durationSeconds: 0).loopLength, nil)
    t.expectEqual(VideoDetails(durationSeconds: .nan).summary, "")
    t.expectEqual(VideoDetails(durationSeconds: -3).summary, "")
}
