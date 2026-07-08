#!/usr/bin/env bash
# Wraps `flutter run` / `flutter build` so the resulting app can identify
# exactly which commit it was built from (see lib/core/build_info.dart and
# the "About" section in Settings).
#
# Usage:
#   ./tool/build_with_version.sh run
#   ./tool/build_with_version.sh run -d macos
#   ./tool/build_with_version.sh build ios --release
#   ./tool/build_with_version.sh build apk --release
set -euo pipefail

cd "$(dirname "$0")/.."

GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
  GIT_COMMIT="${GIT_COMMIT}-dirty"
fi
BUILD_TIME=$(date -u +"%Y-%m-%d %H:%M UTC")

exec flutter "$@" \
  --dart-define="GIT_COMMIT=$GIT_COMMIT" \
  --dart-define="BUILD_TIME=$BUILD_TIME"
