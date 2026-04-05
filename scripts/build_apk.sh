#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBSPEC_PATH="$ROOT_DIR/pubspec.yaml"

current_version="$(grep '^version:' "$PUBSPEC_PATH" | awk '{print $2}')"
version_name="${current_version%%+*}"
version_code="${current_version##*+}"

IFS='.' read -r major minor patch <<<"$version_name"

next_patch=$((patch + 1))
next_code=$((version_code + 1))
next_version="$major.$minor.$next_patch+$next_code"

perl -0pi -e "s/^version: .*/version: $next_version/m" "$PUBSPEC_PATH"

echo "Updated version: $current_version -> $next_version"

cd "$ROOT_DIR"
flutter pub get
flutter build apk --release "$@"
