#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -x "/workspace/env/flutter/bin/flutter" ]]; then
  export PATH="/workspace/env/flutter/bin:$PATH"
elif [[ -x "/opt/flutter/bin/flutter" ]]; then
  export PATH="/opt/flutter/bin:$PATH"
elif [[ -x "/opt/flutter/flutter/bin/flutter" ]]; then
  export PATH="/opt/flutter/flutter/bin:$PATH"
fi

dart_define_args=()
if [[ -n "${OMNITUNE_WEB_APK_URL:-}" ]]; then
  dart_define_args+=(
    "--dart-define=OMNITUNE_WEB_APK_URL=${OMNITUNE_WEB_APK_URL}"
  )
fi
if [[ -n "${OMNITUNE_WEB_WEBDAV_PROXY_BASE_URL:-}" ]]; then
  dart_define_args+=(
    "--dart-define=OMNITUNE_WEB_WEBDAV_PROXY_BASE_URL=${OMNITUNE_WEB_WEBDAV_PROXY_BASE_URL}"
  )
fi

cd "$ROOT_DIR"
flutter pub get
rm -rf "$ROOT_DIR/.dart_tool/flutter_build"
"$ROOT_DIR/scripts/generate_l10n.sh"
flutter build web --release --no-pub "${dart_define_args[@]}" "$@"
