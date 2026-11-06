#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
source "$project_root/scripts/environment.sh"
"$project_root/scripts/bootstrap-resources.sh"
swift build -c release --sdk "$redalert_sdk" --product RedAlertMac
swift build -c release --sdk "$redalert_sdk" --product redalertctl
binary_dir="$(swift build -c release --sdk "$redalert_sdk" --show-bin-path)"
stage_root="$(mktemp -d "$project_root/.build/app-stage.XXXXXX")"
trap 'rm -rf "$stage_root"' EXIT
app_dir="$stage_root/红警作战中心.app"
mkdir -p "$project_root/dist"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/RedAlertMac" "$app_dir/Contents/MacOS/RedAlertMac"
cp "$binary_dir/redalertctl" "$project_root/dist/redalertctl"
if [[ -d "$app_dir/Contents/Resources/RedAlertMac_RedAlertMac.bundle" ]]; then
    rm -rf "$app_dir/Contents/Resources/RedAlertMac_RedAlertMac.bundle"
fi
cp -R "$binary_dir/RedAlertMac_RedAlertMac.bundle" "$app_dir/Contents/Resources/"
swift -sdk "$redalert_sdk" scripts/MakeIcon.swift "$project_root/.build/AppIcon.iconset"
iconutil -c icns "$project_root/.build/AppIcon.iconset" -o "$app_dir/Contents/Resources/AppIcon.icns"
cp scripts/Info.plist "$app_dir/Contents/Info.plist"
cp LICENSE THIRD_PARTY_NOTICES.md "$app_dir/Contents/Resources/"
codesign --force --sign - "$app_dir"
codesign --verify --deep --strict "$app_dir"
final_app="$project_root/dist/红警作战中心.app"
if [[ -d "$final_app" ]]; then
    mv "$final_app" "$stage_root/previous.app"
fi
mv "$app_dir" "$final_app"
printf '\n客户端已构建：%s\n' "$final_app"
