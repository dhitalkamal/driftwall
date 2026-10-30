import SwiftUI
import DriftwallCore

// the fullscreen setting as two cards, each drawing two displays: a fullscreen app on the left
// one, and what happens to the wallpaper on the right one. behaves as a radio group.
struct FullscreenChoiceCards: View {
    let selection: FullscreenBehavior
    let onSelect: (FullscreenBehavior) -> Void

    var body: some View {
        HStack(spacing: 10) {
            card(.muteAudio, title: "Mute sound", detail: "The other display keeps moving, with no sound.")
            card(.pauseAll, title: "Pause wallpaper", detail: "Stops video and sound on every display.")
        }
        // both cards take the taller card's height, so a wrapped description never leaves
        // them uneven.
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Fullscreen app on one display")
    }

    private func card(_ behavior: FullscreenBehavior, title: String, detail: String) -> some View {
        let selected = selection == behavior
        return Button {
            onSelect(behavior)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                DisplayPair(behavior: behavior)
                Text(title).fontWeight(.semibold)
                Text(detail).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 9).fill(selected ? Color.accentColor.opacity(0.07) : .clear))
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(selected ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: selected ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(detail)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

// the pictogram: two small displays on stands.
private struct DisplayPair: View {
    let behavior: FullscreenBehavior

    var body: some View {
        HStack(spacing: 12) {
            display { appWindow }
            display { wallpaper }
        }
        .frame(height: 52)
        .accessibilityHidden(true)
    }

    private func display<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 2) {
            ZStack { content() }
                .padding(2)
                .background(RoundedRectangle(cornerRadius: 3).fill(Color(white: 0.08)))
                .aspectRatio(16 / 10, contentMode: .fit)
            RoundedRectangle(cornerRadius: 1).fill(.secondary.opacity(0.6)).frame(width: 12, height: 3)
        }
        .frame(maxWidth: .infinity)
    }

    // a fullscreen app: a light window with a title bar strip.
    private var appWindow: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color(nsColor: .tertiaryLabelColor)).frame(height: 5)
            Rectangle().fill(Color(nsColor: .controlBackgroundColor))
        }
        .clipShape(RoundedRectangle(cornerRadius: 1.5))
    }

    // the wallpaper wave, bright and muted, or faded, paused and muted. pausing also silences
    // the video, so the pause card shows both icons.
    private var wallpaper: some View {
        ZStack {
            Wave().stroke(Color(red: 0.95, green: 0.7, blue: 0.54), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                .opacity(behavior == .pauseAll ? 0.35 : 1)
                .padding(.horizontal, 6)
                .offset(y: 8)
            HStack(spacing: 5) {
                if behavior == .pauseAll { Image(systemName: "pause.fill") }
                Image(systemName: "speaker.slash.fill")
            }
            .font(.system(size: 11))
            .foregroundStyle(.white)
            .offset(y: -6)
        }
    }
}

// a gentle three-hump wave across the rect's vertical middle.
private struct Wave: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let mid = rect.midY, step = rect.width / 3
        path.move(to: CGPoint(x: rect.minX, y: mid))
        for i in 0..<3 {
            let x0 = rect.minX + CGFloat(i) * step
            path.addCurve(
                to: CGPoint(x: x0 + step, y: mid),
                control1: CGPoint(x: x0 + step * 0.33, y: mid - 5),
                control2: CGPoint(x: x0 + step * 0.66, y: mid + 5)
            )
        }
        return path
    }
}
