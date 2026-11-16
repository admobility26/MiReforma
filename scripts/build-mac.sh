#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
APP="$ROOT/dist/Mi Reforma.app"
rm -rf "$ROOT/dist"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp packaging/Info.plist "$APP/Contents/Info.plist"
cp web/mi_reforma.html "$APP/Contents/Resources/mi_reforma.html"
echo "Compilando Mi Reforma (ARM64)"
xcrun --sdk macosx swiftc -swift-version 5 -parse-as-library -O -target arm64-apple-macosx13.0 \
    src/ReformaApp.swift -framework Cocoa -framework WebKit \
    -o "$APP/Contents/MacOS/MiReforma"
chmod +x "$APP/Contents/MacOS/MiReforma"
plutil -lint "$APP/Contents/Info.plist"
echo "Creando icono de aplicación"
python3 - <<'PY'
import struct,zlib
from pathlib import Path
N=1024
rows=[]
for y in range(N):
    row=bytearray([0])
    for x in range(N):
        r=185; cx=min(max(x,r),N-1-r); cy=min(max(y,r),N-1-r)
        inside=(x-cx)**2+(y-cy)**2<=r*r
        col=(14,107+int(25*y/N),111,255) if inside else (0,0,0,0)
        if 245<=y<=504 and abs(x-512)<=int((y-245)*1.15): col=(250,253,249,255)
        if 337<=x<=687 and 490<=y<=773: col=(250,253,249,255)
        if 454<=x<=572 and 638<=y<=773: col=(13,115,115,255)
        if (379<=x<=433 or 589<=x<=643) and 554<=y<=608: col=(13,115,115,255)
        row.extend(col)
    rows.append(bytes(row))
def chunk(typ,data):
    return struct.pack(">I",len(data))+typ+data+struct.pack(">I",zlib.crc32(typ+data)&0xffffffff)
png=b"\x89PNG\r\n\x1a\n"+chunk(b'IHDR',struct.pack(">IIBBBBB",N,N,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(b''.join(rows),9))+chunk(b'IEND',b'')
Path('dist/icon.png').write_bytes(png)
PY
ICONSET="$ROOT/dist/MiReforma.iconset"
mkdir -p "$ICONSET"
for entry in "16:icon_16x16" "32:icon_16x16@2x" "32:icon_32x32" "64:icon_32x32@2x" "128:icon_128x128" "256:icon_128x128@2x" "256:icon_256x256" "512:icon_256x256@2x" "512:icon_512x512" "1024:icon_512x512@2x"; do
    size="$(echo "$entry" | cut -d: -f1)"
    name="$(echo "$entry" | cut -d: -f2-)"
    sips -s format png -z "$size" "$size" "$ROOT/dist/icon.png" --out "$ICONSET/$name.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/MiReforma.icns"
rm -rf "$ICONSET" "$ROOT/dist/icon.png"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
mkdir -p "$ROOT/dist/staging"
cp -R "$APP" "$ROOT/dist/staging/Mi Reforma.app"
ln -s /Applications "$ROOT/dist/staging/Aplicaciones"
hdiutil create -volname "Mi Reforma" -srcfolder "$ROOT/dist/staging" \
    -ov -format UDZO "$ROOT/dist/MiReforma-AppleSilicon.dmg" >/dev/null
rm -rf "$ROOT/dist/staging"
test -s "$ROOT/dist/MiReforma-AppleSilicon.dmg"
echo "DMG creado: $ROOT/dist/MiReforma-AppleSilicon.dmg"
