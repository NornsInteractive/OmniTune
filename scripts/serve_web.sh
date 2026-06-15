#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -x "/workspace/env/flutter/bin/dart" ]]; then
  export PATH="/workspace/env/flutter/bin:$PATH"
elif [[ -x "/opt/flutter/flutter/bin/dart" ]]; then
  export PATH="/opt/flutter/flutter/bin:$PATH"
fi

cd "$ROOT_DIR"
dart run scripts/serve_web.dart "$@"
