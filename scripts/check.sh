#!/bin/zsh
# These checks use temporary files and isolated UserDefaults suites, never the
# user's clipboard history, saved sources, screenshot folder, or preferences.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "$(uname -s)" != Darwin ]]; then
  print -u2 'These checks require macOS and the Xcode command line tools.'
  exit 1
fi
kapsul_check_cache="${KAPSUL_CHECK_CACHE_DIR:-$HOME/Library/Caches/Kapsul/checks}"
mkdir -p "$kapsul_check_cache/module-cache"
kapsul_check_work="$(mktemp -d "$kapsul_check_cache/run.XXXXXX")"
trap 'rm -rf "$kapsul_check_work"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

print 'Checking shell syntax and JSON resources...'
for kapsul_script in scripts/*.sh; do
  /bin/zsh -n "$kapsul_script"
done
python3 <<'PY'
import json
from pathlib import Path

def unique_keys(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f'Duplicate JSON key: {key}')
        result[key] = value
    return result

resources = sorted(Path('Sources').rglob('*.json'))
if not resources:
    raise SystemExit('No JSON resources found.')
for path in resources:
    with path.open(encoding='utf-8') as file:
        json.load(file, object_pairs_hook=unique_keys)
print(f'{len(resources)} JSON resource(s) validated.')
PY

typeset -a kapsul_swift_args
kapsul_swift_args=(-swift-version 5 -parse-as-library -module-cache-path "$kapsul_check_cache/module-cache")

print 'Running source classification checks...'
xcrun swiftc "${kapsul_swift_args[@]}" Sources/CopyGlass/ClipSource.swift \
  Tests/SourceClassification.swift -o "$kapsul_check_work/source-classification"
"$kapsul_check_work/source-classification"

print 'Running custom source checks...'
xcrun swiftc "${kapsul_swift_args[@]}" Sources/CopyGlass/ClipSource.swift \
  Sources/CopyGlass/AppLocalization.swift Sources/CopyGlass/CustomSource.swift \
  Tests/CustomSourceChecks.swift -o "$kapsul_check_work/custom-sources"
"$kapsul_check_work/custom-sources"

print 'Running localization checks...'
xcrun swiftc "${kapsul_swift_args[@]}" Sources/CopyGlass/AppLocalization.swift \
  Tests/LocalizationChecks.swift -o "$kapsul_check_work/localization"
"$kapsul_check_work/localization" Sources/CopyGlass/Resources/Localizations.json

print 'Running screenshot monitor checks...'
xcrun swiftc "${kapsul_swift_args[@]}" Sources/CopyGlass/ScreenshotMonitor.swift \
  Tests/ScreenshotMonitorChecks.swift -o "$kapsul_check_work/screenshots"
"$kapsul_check_work/screenshots"
print 'Running library feature checks...'
xcrun swiftc "${kapsul_swift_args[@]}" Sources/CopyGlass/ClipModels.swift Sources/CopyGlass/ClipSource.swift \
  Sources/CopyGlass/AppLocalization.swift Sources/CopyGlass/CustomSource.swift Sources/CopyGlass/ClipboardStore.swift \
  Sources/CopyGlass/ScreenshotMonitor.swift Sources/CopyGlass/TextRecognition.swift Sources/CopyGlass/HistoryBackup.swift \
  Tests/LibraryChecks.swift -o "$kapsul_check_work/library"
"$kapsul_check_work/library"
print 'All checks passed.'
