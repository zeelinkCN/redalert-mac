#!/bin/bash
# Prefer the stable SDK when a preview CLT SDK lacks SwiftUI's macro plugin.
if [[ -n "${REDALERT_SDK:-}" ]]; then
    redalert_sdk="$REDALERT_SDK"
elif [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk ]]; then
    redalert_sdk=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
else
    redalert_sdk="$(xcrun --show-sdk-path)"
fi
