#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT_DIR/scripts/build_apk.sh" --dart-define=OMNITUNE_HIDE_CLOUD189=true "$@"
