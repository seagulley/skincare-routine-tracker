#!/bin/bash
# Run tests with code coverage and print metrics.
# Usage: ./scripts/coverage.sh [simulator_name]
# Example: ./scripts/coverage.sh "iPhone 15"

set -e

DESTINATION="${1:-platform=iOS Simulator,name=iPhone 15,OS=17.2}"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESULT_BUNDLE="${PROJECT_ROOT}/Coverage.xcresult"

cd "$PROJECT_ROOT"
rm -rf "$RESULT_BUNDLE"

echo "Running tests with code coverage..."
echo "Destination: $DESTINATION"
echo ""

xcodebuild test \
  -scheme SkincareTracker \
  -destination "$DESTINATION" \
  -enableCodeCoverage YES \
  -resultBundlePath "$RESULT_BUNDLE" \
  -quiet

echo ""
echo "=== Code Coverage Report ==="
xcrun xccov view --report "$RESULT_BUNDLE"

echo ""
echo "Coverage report saved to: $RESULT_BUNDLE"
