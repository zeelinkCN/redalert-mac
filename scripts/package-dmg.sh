#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
stage_root="$(mktemp -d "$project_root/.build/dmg-stage.XXXXXX")"
trap 'rm -rf "$stage_root"' EXIT
ditto "$project_root/dist/红警作战中心.app" "$stage_root/红警作战中心.app"
ln -s /Applications "$stage_root/Applications"
hdiutil create -volname '红警作战中心' -srcfolder "$stage_root" -ov -format UDZO "$project_root/dist/红警作战中心.dmg"
