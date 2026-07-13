#!/bin/bash
# generate scripts/Driftwall.icns from a rendered 1024 png. run once; the icns is committed
# and build_app.sh copies it into the bundle. regenerate if the brand mark changes.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
PNG="$WORK/icon_1024.png"
ICONSET="$WORK/Driftwall.iconset"

# render the base 1024x1024 icon with core graphics (no running app needed).
cat > "$WORK/render.swift" <<'SWIFT'
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { exit(1) }

let rect = CGRect(x: 0, y: 0, width: size, height: size)
// rounded background with a deep blue to teal vertical gradient.
let radius = CGFloat(size) * 0.22
let path = CGPath(roundedRect: rect.insetBy(dx: 8, dy: 8), cornerWidth: radius, cornerHeight: radius, transform: nil)
ctx.addPath(path)
ctx.clip()
let colors = [
    CGColor(red: 0.05, green: 0.09, blue: 0.20, alpha: 1),
    CGColor(red: 0.06, green: 0.42, blue: 0.55, alpha: 1),
] as CFArray
if let grad = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 1]) {
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0), options: [])
}

// three stacked "drift" waves in translucent white.
func wave(yBase: CGFloat, amplitude: CGFloat, alpha: CGFloat) {
    let w = CGFloat(size)
    let p = CGMutablePath()
    p.move(to: CGPoint(x: 0, y: yBase))
    var x: CGFloat = 0
    while x <= w {
        let y = yBase + sin(x / w * .pi * 2) * amplitude
        p.addLine(to: CGPoint(x: x, y: y))
        x += 8
    }
    p.addLine(to: CGPoint(x: w, y: 0))
    p.addLine(to: CGPoint(x: 0, y: 0))
    p.closeSubpath()
    ctx.addPath(p)
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: alpha))
    ctx.fillPath()
}
wave(yBase: CGFloat(size) * 0.42, amplitude: CGFloat(size) * 0.05, alpha: 0.14)
wave(yBase: CGFloat(size) * 0.34, amplitude: CGFloat(size) * 0.06, alpha: 0.18)
wave(yBase: CGFloat(size) * 0.26, amplitude: CGFloat(size) * 0.07, alpha: 0.24)

guard let image = ctx.makeImage() else { exit(1) }
let outURL = URL(fileURLWithPath: CommandLine.arguments[1])
guard let dest = CGImageDestinationCreateWithURL(outURL as CFURL, UTType.png.identifier as CFString, 1, nil) else { exit(1) }
CGImageDestinationAddImage(dest, image, nil)
if !CGImageDestinationFinalize(dest) { exit(1) }
SWIFT

swift "$WORK/render.swift" "$PNG"

mkdir -p "$ICONSET"
for sz in 16 32 64 128 256 512 1024; do
	sips -z "$sz" "$sz" "$PNG" --out "$ICONSET/icon_${sz}x${sz}.png" >/dev/null
done
# retina variants expected by iconutil
cp "$ICONSET/icon_32x32.png"   "$ICONSET/icon_16x16@2x.png"
cp "$ICONSET/icon_64x64.png"   "$ICONSET/icon_32x32@2x.png"
cp "$ICONSET/icon_256x256.png" "$ICONSET/icon_128x128@2x.png"
cp "$ICONSET/icon_512x512.png" "$ICONSET/icon_256x256@2x.png"
cp "$ICONSET/icon_1024x1024.png" "$ICONSET/icon_512x512@2x.png"
rm -f "$ICONSET/icon_64x64.png" "$ICONSET/icon_1024x1024.png"

iconutil -c icns "$ICONSET" -o "$ROOT/scripts/Driftwall.icns"
rm -rf "$WORK"
echo "wrote scripts/Driftwall.icns"
