#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ensure_flutter_on_path() {
  if command -v flutter >/dev/null 2>&1; then
    return
  fi

  local candidate
  for candidate in \
    "/workspace/env/flutter/bin" \
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

APK_URL="${OMNITUNE_WEB_APK_URL:-}"

if [[ -z "$APK_URL" ]]; then
  echo "OMNITUNE_WEB_APK_URL is required"
  echo "Example: OMNITUNE_WEB_APK_URL=https://example.com/omnitune.apk ./scripts/run_web_server.sh"
  exit 1
fi

cd "$ROOT_DIR"
flutter pub get
dart_define_args=("--dart-define=OMNITUNE_WEB_APK_URL=$APK_URL")
if [[ -n "${OMNITUNE_WEB_WEBDAV_PROXY_BASE_URL:-}" ]]; then
  dart_define_args+=(
    "--dart-define=OMNITUNE_WEB_WEBDAV_PROXY_BASE_URL=${OMNITUNE_WEB_WEBDAV_PROXY_BASE_URL}"
  )
fi

flutter run -d web-server "${dart_define_args[@]}" "$@"
