#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
if [[ ! -d "$project_root/dist/红警作战中心.app" ]]; then
    "$project_root/scripts/build.sh"
fi
open "$project_root/dist/红警作战中心.app"
