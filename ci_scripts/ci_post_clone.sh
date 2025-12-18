#!/bin/sh

# ci_post_clone.sh - Xcode Cloud standard approach for secrets
# Injects FAL_KEY into Info.plist at build time

set -e

echo "Injecting FAL_KEY into Info.plist..."

PLIST_PATH="$CI_PRIMARY_REPOSITORY_PATH/Info.plist"

/usr/libexec/PlistBuddy -c "Set :FAL_KEY $FAL_KEY" "$PLIST_PATH"

echo "FAL_KEY injected successfully"
