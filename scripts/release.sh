#!/bin/zsh
# Publie une nouvelle version de NewsFlux.
#
# Usage : scripts/release.sh 1.2.0 [notes.md]
#
# Étapes : numéro de version → commit + tag → envoi sur GitHub → .app → zip
# → appcast.xml signé (clé privée Sparkle du trousseau, compte « NewsFlux »)
# → release GitHub avec le zip et appcast.xml.
# Les apps installées trouvent la mise à jour via
# https://github.com/RoBuys/NewsFlux/releases/latest/download/appcast.xml
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?Usage : scripts/release.sh <version> [notes.md]}"
NOTES="${2:-}"
TAG="v$VERSION"
REPO="RoBuys/NewsFlux"
PLIST="Resources/Info.plist"
SPARKLE_BIN=".build/artifacts/sparkle/Sparkle/bin"

[[ "$(git branch --show-current)" == "main" ]] || { echo "❌ Publiez depuis la branche main."; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo "❌ Des modifications ne sont pas commitées."; exit 1; }
git rev-parse "$TAG" >/dev/null 2>&1 && { echo "❌ Le tag $TAG existe déjà."; exit 1; }

# 1. Numéro de version (CFBundleVersion, entier croissant, sert à comparer les versions).
BUILD=$(( $(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST") + 1 ))
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" -c "Set :CFBundleVersion $BUILD" "$PLIST"
git commit -q -m "Version $VERSION" "$PLIST"
git tag -a "$TAG" -m "NewsFlux $VERSION"
git push -q origin main "$TAG"

# 2. Application et archive.
./scripts/build-app.sh
RELEASE_DIR="build/release-$VERSION"
rm -rf "$RELEASE_DIR" && mkdir -p "$RELEASE_DIR"
ZIP="$RELEASE_DIR/NewsFlux-$VERSION.zip"
ditto -c -k --keepParent build/NewsFlux.app "$ZIP"

# 3. Appcast signé.
"$SPARKLE_BIN/generate_appcast" --account NewsFlux \
    --download-url-prefix "https://github.com/$REPO/releases/download/$TAG/" \
    --link "https://github.com/$REPO" \
    "$RELEASE_DIR"

# 4. Release GitHub.
if [[ -n "$NOTES" ]]; then
    gh release create "$TAG" "$ZIP" "$RELEASE_DIR/appcast.xml" --repo "$REPO" \
        --title "NewsFlux $VERSION" --notes-file "$NOTES"
else
    gh release create "$TAG" "$ZIP" "$RELEASE_DIR/appcast.xml" --repo "$REPO" \
        --title "NewsFlux $VERSION" --generate-notes
fi
echo "✅ NewsFlux $VERSION publiée."
