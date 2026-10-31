import SwiftUI
import UniformTypeIdentifiers
import DriftwallCore

// a miniature of the main display: its real aspect ratio, a menu bar strip, the notch when the
// Mac has one, and the startup disk icon. the video still is drawn with the chosen fit and dim,
// so the user judges both against real desktop furniture. accepts a dropped video file.
struct ScreenPreview: View {
    let image: NSImage?
    let fitMode: FitMode
    let dim: Double
    let onDropVideo: (URL) -> Void
    @State private var targeted = false

    private let screen = ScreenShape.main

    var body: some View {
        GeometryReader { geo in
            let barHeight = max(9, geo.size.height * screen.menuBarFraction)
            ZStack(alignment: .topLeading) {
                wallpaper(in: geo.size)
                Color.black.opacity(dim)
                menuBar(height: barHeight)
                if let notchFraction = screen.notchWidthFraction {
                    UnevenRoundedCorners(radius: 6)
                        .fill(.black)
                        .frame(width: geo.size.width * notchFraction, height: barHeight)
                        .frame(maxWidth: .infinity)
                }
                diskIcon(width: geo.size.width)
                    .padding(.top, barHeight + geo.size.height * 0.035)
                    .padding(.trailing, geo.size.width * 0.026)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .aspectRatio(screen.aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(5)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.08)))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(targeted ? Color.accentColor : Color.white.opacity(0.08), lineWidth: targeted ? 3 : 0.5)
        )
        .shadow(color: .black.opacity(0.22), radius: 12, y: 8)
        .onDrop(of: [UTType.fileURL], isTargeted: $targeted) { providers in
            handleDrop(providers)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(image == nil ? "No wallpaper. Drop a video here." : "Wallpaper preview, \(fitMode.rawValue), dimmed \(Int(dim * 100)) percent")
    }

    // the still with the same gravity the wallpaper uses. Fit mirrors the app's blurred fill
    // behind letterboxed video; with no video, a plain desktop gradient invites a drop.
    @ViewBuilder
    private func wallpaper(in size: CGSize) -> some View {
        if let image {
            switch fitMode {
            case .fill:
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height).clipped()
            case .fit:
                ZStack {
                    Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                        .frame(width: size.width, height: size.height).clipped()
                        .blur(radius: 18).brightness(-0.15)
                    Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
                }
                .frame(width: size.width, height: size.height).clipped()
            case .stretch:
                Image(nsImage: image).resizable().frame(width: size.width, height: size.height)
            }
        } else {
            ZStack {
                LinearGradient(colors: [Color(red: 0.24, green: 0.31, blue: 0.4), Color(red: 0.11, green: 0.15, blue: 0.21)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                VStack(spacing: 4) {
                    Text("No wallpaper").font(.headline)
                    Text("Drag a video here, or choose one below.").font(.callout).opacity(0.8)
                }
                .foregroundStyle(.white)
            }
            .frame(width: size.width, height: size.height)
        }
    }

    // a translucent strip with placeholder menu titles and status items.
    private func menuBar(height: CGFloat) -> some View {
        HStack(spacing: 6) {
            ForEach([6.0, 14, 10, 12], id: \.self) { capsule(width: $0) }
            Spacer()
            ForEach([8.0, 8.5, 22], id: \.self) { capsule(width: $0) }
        }
        .padding(.horizontal, 10)
        .frame(height: height)
        .background(.ultraThinMaterial.opacity(0.7))
        .environment(\.colorScheme, .dark)
    }

    private func capsule(width: Double) -> some View {
        Capsule().fill(.white.opacity(0.75)).frame(width: width, height: 3)
    }

    private func diskIcon(width: CGFloat) -> some View {
        VStack(spacing: 2) {
            Image(nsImage: screen.diskIcon).resizable().frame(width: width * 0.06, height: width * 0.06)
            Text(screen.diskName).font(.system(size: 9)).foregroundStyle(.white)
                .shadow(color: .black.opacity(0.6), radius: 1, y: 1)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            Task { @MainActor in
                // refuse documents, images and folders so they never replace the wallpaper.
                guard VideoFileTypes.isSupported(url) else { NSSound.beep(); return }
                onDropVideo(url)
            }
        }
        return true
    }
}

// a notch shape: square top corners, rounded bottom corners. UnevenRoundedRectangle needs
// macOS 14, so this draws the same thing for macOS 13.
private struct UnevenRoundedCorners: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = min(radius, rect.height, rect.width / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// the facts about the main display the preview imitates, read once.
@MainActor
private struct ScreenShape {
    let aspectRatio: CGFloat
    let menuBarFraction: CGFloat
    // notch width as a fraction of screen width, nil on displays without a notch.
    let notchWidthFraction: CGFloat?
    let diskIcon: NSImage
    let diskName: String

    static let main: ScreenShape = {
        let screen = NSScreen.main
        let frame = screen?.frame ?? CGRect(x: 0, y: 0, width: 1512, height: 982)
        let topInset = screen?.safeAreaInsets.top ?? 0
        var notch: CGFloat?
        if topInset > 0, let screen,
           let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            notch = (frame.width - left.width - right.width) / frame.width
        }
        // the menu bar is as tall as the notch where there is one, 24pt elsewhere.
        let barHeight = topInset > 0 ? topInset : 24
        return ScreenShape(
            aspectRatio: frame.width / max(frame.height, 1),
            menuBarFraction: barHeight / max(frame.height, 1),
            notchWidthFraction: notch,
            diskIcon: NSWorkspace.shared.icon(forFile: "/"),
            diskName: FileManager.default.displayName(atPath: "/")
        )
    }()
}
