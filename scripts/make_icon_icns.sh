#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ICON_DIR="$ROOT_DIR/assets/icon"
ICONSET_DIR="$ICON_DIR/MustDo.iconset"
BASE_PNG="$ICON_DIR/MustDo-1024.png"
ICNS_OUT="$ICON_DIR/MustDo.icns"

mkdir -p "$ICON_DIR"

cat > "$ICON_DIR/generate_icon.swift" <<'SWIFT'
import AppKit
import Foundation

let outPath = CommandLine.arguments[1]
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)

image.lockFocus()

let rect = NSRect(origin: .zero, size: size)
let bg = NSBezierPath(roundedRect: rect.insetBy(dx: 64, dy: 64), xRadius: 220, yRadius: 220)
NSColor(calibratedRed: 0.98, green: 0.86, blue: 0.40, alpha: 1).setFill()
bg.fill()

let accent = NSBezierPath(roundedRect: NSRect(x: 120, y: 140, width: 784, height: 140), xRadius: 40, yRadius: 40)
NSColor(calibratedRed: 0.96, green: 0.68, blue: 0.22, alpha: 1).setFill()
accent.fill()

let text = "M"
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 560, weight: .bold),
    .foregroundColor: NSColor(calibratedWhite: 0.12, alpha: 1),
    .paragraphStyle: paragraph
]
let attributed = NSAttributedString(string: text, attributes: attrs)
attributed.draw(in: NSRect(x: 0, y: 255, width: 1024, height: 600))

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("failed to render icon")
}

try pngData.write(to: URL(fileURLWithPath: outPath))
SWIFT

swift "$ICON_DIR/generate_icon.swift" "$BASE_PNG"

rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

sips -z 16 16     "$BASE_PNG" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32     "$BASE_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32     "$BASE_PNG" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64     "$BASE_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128   "$BASE_PNG" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256   "$BASE_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$BASE_PNG" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512   "$BASE_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "$BASE_PNG" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
cp "$BASE_PNG" "$ICONSET_DIR/icon_512x512@2x.png"

iconutil -c icns "$ICONSET_DIR" -o "$ICNS_OUT"

echo "Icon created: $ICNS_OUT"
