#!/bin/zsh
# Compile NewsFlux en mode release et l'emballe dans build/NewsFlux.app
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/NewsFlux"
APP="build/NewsFlux.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/NewsFlux"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Signature ad hoc pour pouvoir lancer l'app localement.
codesign --force --sign - "$APP"
echo "✅ $APP prête. Lancez-la avec : open $APP"
