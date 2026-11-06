#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
source "$project_root/scripts/environment.sh"
swift run --sdk "$redalert_sdk" RedAlertChecks
