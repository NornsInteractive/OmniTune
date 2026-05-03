#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBSPEC_PATH="$ROOT_DIR/pubspec.yaml"

if [[ -x "/opt/flutter/flutter/bin/flutter" ]]; then
  export PATH="/opt/flutter/flutter/bin:$PATH"
fi

if [[ -d "/usr/local/sdkman/candidates/java/21.0.10-ms" ]]; then
  export JAVA_HOME="/usr/local/sdkman/candidates/java/21.0.10-ms"
  export PATH="$JAVA_HOME/bin:$PATH"
fi

if [[ -d "/home/codespace/android-sdk" ]]; then
  export ANDROID_SDK_ROOT="/home/codespace/android-sdk"
  export ANDROID_HOME="$ANDROID_SDK_ROOT"
fi

export GRADLE_OPTS="${GRADLE_OPTS:-} -Dorg.gradle.daemon=false -Dorg.gradle.workers.max=1"

gradle_dart_defines=()
for arg in "$@"; do
  case "$arg" in
    --dart-define=*)
      define_value="${arg#--dart-define=}"
      gradle_dart_defines+=(
        "$(printf '%s' "$define_value" | base64 | tr -d '\n')"
      )
      ;;
  esac
done

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
rm -rf "$ROOT_DIR/.dart_tool/flutter_build"
flutter build apk --release --config-only --no-pub "$@"

cd "$ROOT_DIR/android"
gradle_args=(assembleRelease --no-daemon -Dorg.gradle.workers.max=1)
if [[ ${#gradle_dart_defines[@]} -gt 0 ]]; then
  gradle_args+=("-Pdart-defines=$(IFS=,; echo "${gradle_dart_defines[*]}")")
fi
./gradlew "${gradle_args[@]}"
