#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBSPEC_PATH="$ROOT_DIR/pubspec.yaml"
ANDROID_DIR="$ROOT_DIR/android"
KEYSTORE_PATH="$ANDROID_DIR/upload-keystore.jks"
KEY_PROPERTIES_PATH="$ANDROID_DIR/key.properties"
KEY_ALIAS="omnituneUpload"
AAB_OUTPUT="$ROOT_DIR/build/app/outputs/bundle/release/app-release.aab"
APK_OUTPUT="$ROOT_DIR/build/app/outputs/flutter-apk/app-release.apk"
TMP_ROOT="${TMPDIR:-${CODEX_TMP_ROOT:-/opt/tmp}}"
GRADLE_HOME="${GRADLE_USER_HOME:-${CODEX_GRADLE_HOME:-/opt/gradle-home}}"
PUB_CACHE_ROOT="${PUB_CACHE:-${CODEX_PUB_CACHE:-/opt/pub-cache}}"

ensure_flutter_on_path() {
  if command -v flutter >/dev/null 2>&1; then
    return
  fi

  local candidate
  for candidate in \
    "/workspace/env/flutter/bin" \
    "/opt/flutter/bin" \
    "/opt/flutter/flutter/bin" \
    "/usr/local/flutter/bin" \
    "/workspace/flutter/bin"
  do
    if [[ -x "$candidate/flutter" ]]; then
      export PATH="$candidate:$PATH"
      return
    fi
  done
}

ensure_flutter_on_path

mkdir -p "$TMP_ROOT"
mkdir -p "$GRADLE_HOME"
mkdir -p "$PUB_CACHE_ROOT"
export TMPDIR="$TMP_ROOT"
export GRADLE_USER_HOME="$GRADLE_HOME"
export PUB_CACHE="$PUB_CACHE_ROOT"
export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-} -Djava.io.tmpdir=$TMPDIR"

random_secret() {
  LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32
  printf '\n'
}

ensure_upload_keystore() {
  if [[ -f "$KEY_PROPERTIES_PATH" && -f "$KEYSTORE_PATH" ]]; then
    return
  fi

  if [[ -f "$KEY_PROPERTIES_PATH" || -f "$KEYSTORE_PATH" ]]; then
    echo "Release signing files are incomplete. Keep both $KEY_PROPERTIES_PATH and $KEYSTORE_PATH in sync." >&2
    exit 1
  fi

  local store_password
  store_password="$(random_secret)"

  keytool -genkeypair \
    -keystore "$KEYSTORE_PATH" \
    -storetype PKCS12 \
    -storepass "$store_password" \
    -keypass "$store_password" \
    -alias "$KEY_ALIAS" \
    -keyalg RSA \
    -keysize 4096 \
    -validity 10000 \
    -dname "CN=OmniTune Upload, OU=Release, O=OmniTune, L=Unknown, ST=Unknown, C=US"

  cat >"$KEY_PROPERTIES_PATH" <<EOF
storeFile=$(basename "$KEYSTORE_PATH")
storePassword=$store_password
keyAlias=$KEY_ALIAS
keyPassword=$store_password
EOF

  chmod 600 "$KEYSTORE_PATH" "$KEY_PROPERTIES_PATH"

  echo "Generated Android upload key:"
  echo "  Keystore: $KEYSTORE_PATH"
  echo "  Properties: $KEY_PROPERTIES_PATH"
  echo "Back up both files before publishing to Play Console."
}

if [[ -d "/usr/local/sdkman/candidates/java/21.0.10-ms" ]]; then
  export JAVA_HOME="/usr/local/sdkman/candidates/java/21.0.10-ms"
  export PATH="$JAVA_HOME/bin:$PATH"
fi

if [[ -d "/home/codespace/android-sdk" ]]; then
  export ANDROID_SDK_ROOT="/home/codespace/android-sdk"
  export ANDROID_HOME="$ANDROID_SDK_ROOT"
fi

export GRADLE_OPTS="${GRADLE_OPTS:-} -Dorg.gradle.daemon=false -Dorg.gradle.workers.max=1"

ensure_upload_keystore

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
flutter --no-version-check pub get
rm -rf "$ROOT_DIR/.dart_tool/flutter_build"
flutter --no-version-check build appbundle --release --no-pub "$@"
flutter --no-version-check build apk --release --no-pub "$@"

echo "Generated Play bundle: $AAB_OUTPUT"
echo "Generated signed APK: $APK_OUTPUT"
