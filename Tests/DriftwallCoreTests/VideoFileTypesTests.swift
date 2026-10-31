import Foundation
import DriftwallCore

func runVideoFileTypesTests(_ t: TestRunner) {
    // the formats Driftwall plays, in any letter case.
    for name in ["clip.mp4", "clip.m4v", "clip.mov", "CLIP.MOV", "Ocean.Mp4"] {
        t.expect(VideoFileTypes.isSupported(URL(fileURLWithPath: "/tmp/\(name)")), "\(name) should be accepted")
    }
    // anything else is refused before it can replace a working wallpaper.
    for name in ["notes.txt", "photo.jpg", "archive.zip", "clip", "clip.mp4.txt", "folder/"] {
        t.expect(!VideoFileTypes.isSupported(URL(fileURLWithPath: "/tmp/\(name)")), "\(name) should be refused")
    }
}
