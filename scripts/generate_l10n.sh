#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="$ROOT_DIR/.dart_tool/omnitune_l10n"
TARGET_DIR="$ROOT_DIR/lib/core/i18n"

cd "$ROOT_DIR"
flutter gen-l10n
rm -rf "$TARGET_DIR"
mkdir -p "$TARGET_DIR"
cp "$SOURCE_DIR/app_localizations.dart" "$TARGET_DIR/localizations.dart"
cp "$SOURCE_DIR/app_localizations_en.dart" "$TARGET_DIR/localizations_en.dart"
cp "$SOURCE_DIR/app_localizations_zh.dart" "$TARGET_DIR/localizations_zh.dart"
sed -i \
  -e "s/import 'app_localizations_en.dart';/import 'localizations_en.dart';/" \
  -e "s/import 'app_localizations_zh.dart';/import 'localizations_zh.dart';/" \
  "$TARGET_DIR/localizations.dart"
sed -i \
  -e "s/import 'app_localizations.dart';/import 'localizations.dart';/" \
  "$TARGET_DIR/localizations_en.dart" \
  "$TARGET_DIR/localizations_zh.dart"
