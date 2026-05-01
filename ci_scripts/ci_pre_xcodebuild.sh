#!/bin/zsh -e
# Xcode Cloud CI pre-build: set CFBundleVersion via shared next-build-number.py helper.
#
# This script runs in Xcode Cloud right before xcodebuild starts.
# It queries App Store Connect for max(CFBundleVersion) on the current
# marketing version (preReleaseVersion train) and sets CFBundleVersion to max+1.
# This ensures build numbers stay strictly monotonic across all runners
# (XCC + self-hosted).
#
# The helper ci_scripts/lib/next-build-number.py requires:
#   ASC_KEY_ID, ASC_ISSUER_ID, and one of:
#   - ASC_KEY_CONTENT (preferred)
#   - ASC_KEY_PATH (per-runner file)
#   - ASC_PRIVATE_KEY (fallback)
#
# If the helper fails (network issue, ASC API down), falls back to
# CI_BUILD_NUMBER + offset. This ensures XCC ships are never blocked by
# transient API failures.

APP_ID="6760988141"   # DocArmor
TRAIN=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
  "$CI_PRIMARY_REPOSITORY_PATH/DocArmor/Info.plist" 2>/dev/null \
  | sed 's/\$(MARKETING_VERSION)//' || echo "")
# Info.plist uses $(MARKETING_VERSION) — extract the literal value from
# pbxproj (all targets share it; first match is fine).
if [ -z "$TRAIN" ] || [ "$TRAIN" = "\$(MARKETING_VERSION)" ]; then
  TRAIN=$(grep -m1 "MARKETING_VERSION = " "$CI_PRIMARY_REPOSITORY_PATH/DocArmor.xcodeproj/project.pbxproj" \
    | sed -E 's/.*MARKETING_VERSION = ([^;]+);.*/\1/')
fi
echo "marketing train: $TRAIN"

BUILD_NUM=""
if [ -n "$TRAIN" ] && [ -n "${ASC_KEY_ID:-}" ] && [ -n "${ASC_ISSUER_ID:-}" ] && \
   { [ -n "${ASC_KEY_CONTENT:-}" ] || [ -n "${ASC_PRIVATE_KEY:-}" ]; }; then
  if BUILD_NUM=$(python3 "$CI_PRIMARY_REPOSITORY_PATH/ci_scripts/lib/next-build-number.py" \
                   --app-id "$APP_ID" --train "$TRAIN" --floor 1 2>&1); then
    echo "ASC-resolved next build: $BUILD_NUM"
  else
    echo "ASC helper failed: $BUILD_NUM"
    BUILD_NUM=""
  fi
fi
if [ -z "$BUILD_NUM" ]; then
  BUILD_NUM=$((CI_BUILD_NUMBER + 100))
  echo "fallback formula: CI_BUILD_NUMBER + 100 = $BUILD_NUM"
fi
echo "ci_pre_xcodebuild: setting CFBundleVersion to $BUILD_NUM on all targets"
cd "$CI_PRIMARY_REPOSITORY_PATH"
XCPROJ=$(ls -d *.xcodeproj 2>/dev/null | head -1)
if [ -z "$XCPROJ" ]; then
  echo "no .xcodeproj at repo root, searching..."
  XCPROJ=$(find . -maxdepth 3 -name "*.xcodeproj" | head -1)
fi
echo "target project: $XCPROJ"
if [ -n "$XCPROJ" ]; then
  cd "$(dirname "$XCPROJ")"
  if ! agvtool new-version -all "$BUILD_NUM"; then
    echo "agvtool failed, falling back to PlistBuddy on all Info.plists"
    cd "$CI_PRIMARY_REPOSITORY_PATH"
    find . -name "Info.plist" -not -path "*/Pods/*" -not -path "*/fastlane/*" -not -path "*/Tests*" -not -path "*/UITests*" | while read p; do
      if /usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$p" >/dev/null 2>&1; then
        /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUM" "$p" && echo "bumped: $p"
      fi
    done
  fi
fi
echo "ci_pre_xcodebuild: done"
