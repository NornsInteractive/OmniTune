#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ensure_dart_on_path() {
  if command -v dart >/dev/null 2>&1; then
    return
  fi

  local candidate
  for candidate in \
    "/workspace/env/flutter/bin" \
    "/opt/flutter/flutter/bin" \
    "/usr/local/flutter/bin" \
    "/workspace/flutter/bin"
  do
    if [[ -x "$candidate/dart" ]]; then
      export PATH="$candidate:$PATH"
      return
    fi
  done
}

ensure_dart_on_path

cd "$ROOT_DIR"
dart run scripts/webdav_proxy.dart "$@"
