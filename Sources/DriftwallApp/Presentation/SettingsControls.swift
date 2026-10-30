import SwiftUI

// shared building blocks for the settings tabs: an inset group like System Settings, a row with
// an optional hint line, and an icon slider row. every tab lays out with these so spacing and
// edges match across tabs.

// one size and one spacing scale for every tab. all tabs share the same page size, so the
// window never grows or shrinks when switching tabs, and gaps read the same everywhere.
enum SettingsMetrics {
    static let width: CGFloat = 560
    // fits the Wallpaper tab, the tallest; shorter tabs leave space below their content.
    static let height: CGFloat = 640
    static let pagePadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 20
    static let headerSpacing: CGFloat = 6
    static let rowInset: CGFloat = 12
    static let rowVertical: CGFloat = 8
    static let rowMinHeight: CGFloat = 40
    static let cornerRadius: CGFloat = 10
}

// the fixed-size page every tab lays out in. sections stack top-down with the section gap;
// content taller than the page (a long playlist) scrolls instead of growing the window.
struct SettingsPage<Content: View>: View {
    // the About tab centers its content; every other tab is top-aligned.
    var centered = false
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: SettingsMetrics.sectionSpacing) {
                content
            }
            .padding(SettingsMetrics.pagePadding)
            .frame(maxWidth: .infinity, minHeight: SettingsMetrics.height,
                   alignment: centered ? .center : .top)
        }
        .frame(width: SettingsMetrics.width, height: SettingsMetrics.height)
    }
}

// a divider inset by the row padding on both sides, so separators never touch the group edge.
struct RowDivider: View {
    var leadingInset: CGFloat = SettingsMetrics.rowInset

    var body: some View {
        Divider().padding(.leading, leadingInset).padding(.trailing, SettingsMetrics.rowInset)
    }
}

// a rounded group of rows separated by hairlines, with an optional header above it.
struct SettingsGroup<Content: View>: View {
    var header: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: SettingsMetrics.headerSpacing) {
            if let header {
                Text(header)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
            VStack(spacing: 0) {
                // rows draw their own top divider; the first row of a group passes isFirst.
                content
            }
            .background(Color(nsColor: .controlBackgroundColor),
                        in: RoundedRectangle(cornerRadius: SettingsMetrics.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: SettingsMetrics.cornerRadius).strokeBorder(.separator, lineWidth: 0.5))
        }
    }
}

// one row: a title with an optional hint underneath, and a trailing control.
struct SettingsRow<Trailing: View>: View {
    let title: String
    var hint: String?
    // the first row of a group skips the top divider.
    var isFirst = false
    @ViewBuilder var trailing: Trailing

    var body: some View {
        VStack(spacing: 0) {
            if !isFirst { RowDivider() }
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                    if let hint {
                        Text(hint).font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                trailing
            }
            .padding(.horizontal, SettingsMetrics.rowInset)
            .padding(.vertical, SettingsMetrics.rowVertical)
            .frame(minHeight: SettingsMetrics.rowMinHeight)
        }
    }
}

// a switch row, the most common case.
struct ToggleRow: View {
    let title: String
    var hint: String?
    var isFirst = false
    let isOn: Binding<Bool>

    var body: some View {
        SettingsRow(title: title, hint: hint, isFirst: isFirst) {
            Toggle(title, isOn: isOn).labelsHidden().toggleStyle(.switch).controlSize(.small)
        }
    }
}

// icon, label, slider, and the current value, aligned on a grid so stacked sliders line up.
struct SliderRow: View {
    let symbol: String
    let title: String
    let value: Binding<Double>
    let range: ClosedRange<Double>
    var step: Double?
    let valueText: String

    var body: some View {
        VStack(spacing: 0) {
            RowDivider()
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                    .accessibilityHidden(true)
                Text(title).frame(width: 64, alignment: .leading)
                slider
                Text(valueText)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
            .padding(.horizontal, SettingsMetrics.rowInset)
            .padding(.vertical, SettingsMetrics.rowVertical)
            .frame(minHeight: SettingsMetrics.rowMinHeight)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var slider: some View {
        if let step {
            Slider(value: value, in: range, step: step) { Text(title) }.labelsHidden()
        } else {
            Slider(value: value, in: range) { Text(title) }.labelsHidden()
        }
    }
}
