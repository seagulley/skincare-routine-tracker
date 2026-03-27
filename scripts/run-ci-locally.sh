#!/usr/bin/env bash
# Mirrors .github/workflows/ci.yml so you can dry-run the same steps before pushing.
# Usage (from repo root): ./scripts/run-ci-locally.sh
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

export CI=true
export DERIVED_DATA="${DERIVED_DATA:-$REPO_ROOT/.derivedData}"

echo "==> Repo: $REPO_ROOT"
echo "==> DERIVED_DATA: $DERIVED_DATA"
echo "==> CI=$CI (matches GitHub Actions for notification permission handling)"

UDID=$(python3 <<'PY'
import json, subprocess, sys
raw = subprocess.check_output(
    ["xcrun", "simctl", "list", "devices", "available", "-j"], text=True
)
for devices in json.loads(raw).get("devices", {}).values():
    for d in devices:
        if d.get("isAvailable") and str(d.get("name", "")).startswith("iPhone"):
            print(d["udid"])
            sys.exit(0)
sys.exit(1)
PY
)

echo "==> Simulator UDID: $UDID"
xcrun simctl boot "$UDID" 2>/dev/null || true

echo "==> xcodebuild build-for-testing"
xcodebuild build-for-testing \
  -project SkincareTracker.xcodeproj \
  -scheme SkincareTracker \
  -sdk iphonesimulator \
  -destination "platform=iOS Simulator,id=${UDID}" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGN_IDENTITY="-"

echo "==> xcodebuild test-without-building"
xcodebuild test-without-building \
  -project SkincareTracker.xcodeproj \
  -scheme SkincareTracker \
  -sdk iphonesimulator \
  -destination "platform=iOS Simulator,id=${UDID}" \
  -derivedDataPath "$DERIVED_DATA" \
  -parallel-testing-enabled NO \
  CODE_SIGN_IDENTITY="-"

echo "==> CI dry run finished successfully."
