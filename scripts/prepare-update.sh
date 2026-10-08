#!/bin/zsh
# Prepare a signed update archive and appcast; never publish implicitly.
set -euo pipefail
cd "$(dirname "$0")/.."
kapsul_tools="${COPYGLASS_BUILD_DIR:-$HOME/Library/Caches/CopyGlass/build}/artifacts/sparkle/Sparkle/bin"
python3 <<'PY'
import json, os, plistlib, shutil, subprocess, tempfile
from pathlib import Path
app = Path('dist/Kapsül.app')
info = plistlib.loads((app/'Contents/Info.plist').read_bytes())
config = json.loads(Path('Config/updates.json').read_text())
if info['SUPublicEDKey'] != config['publicEDKey']:
    raise SystemExit('App signing key does not match Config/updates.json.')
archs = subprocess.check_output(['lipo', '-archs', str(app/'Contents/MacOS/CopyGlass')], text=True).split()
if set(archs) != {'arm64', 'x86_64'}:
    raise SystemExit('Updates must include both arm64 and x86_64. Build with --universal.')

version = info['CFBundleShortVersionString']
updates = Path('dist/updates')
updates.mkdir(exist_ok=True)
# Each release contains one complete universal update, with no stale archives.
for path in updates.iterdir():
    if path.is_file():
        path.unlink()
archive = updates/f'Kapsul-{version}-universal.zip'
cache = Path(os.environ.get('KAPSUL_PACKAGE_CACHE_DIR', str(Path.home()/'Library/Caches/Kapsul/packaging')))
cache.mkdir(parents=True, exist_ok=True)
def copy_clean(source, destination):
    shutil.copyfile(source, destination)
    shutil.copymode(source, destination)
    return destination
with tempfile.TemporaryDirectory(prefix='update-', dir=cache) as work:
    staged = Path(work)/app.name
    shutil.copytree(app, staged, symlinks=True, copy_function=copy_clean)
    subprocess.run(['xattr', '-cr', str(staged)], check=True)
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(staged)], check=True)
    subprocess.run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(staged), str(archive.resolve())], check=True)
notes = Path(f'docs/releases/v{version}.md')
if notes.exists():
    archive.with_suffix('.md').write_bytes(notes.read_bytes())
PY
kapsul_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' 'dist/Kapsül.app/Contents/Info.plist')"
kapsul_account="$(python3 -c 'import json; print(json.load(open("Config/updates.json"))["keychainAccount"])')"
typeset -a kapsul_sign_args
kapsul_sign_args=(--account "$kapsul_account")
if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
  kapsul_sign_args=(--ed-key-file -)
  print -rn -- "$SPARKLE_PRIVATE_KEY" | "$kapsul_tools/generate_appcast" "${kapsul_sign_args[@]}" \
    --download-url-prefix "https://github.com/bugraozgenc-dotcom/kapsul/releases/download/v${kapsul_version}/" \
    --embed-release-notes --maximum-deltas 0 dist/updates
else
  "$kapsul_tools/generate_appcast" "${kapsul_sign_args[@]}" \
    --download-url-prefix "https://github.com/bugraozgenc-dotcom/kapsul/releases/download/v${kapsul_version}/" \
    --embed-release-notes --maximum-deltas 0 dist/updates
fi
python3 <<'PY'
import json, subprocess, xml.etree.ElementTree as ET
from pathlib import Path
root = ET.parse('dist/updates/appcast.xml').getroot()
items = root.findall('./channel/item')
assert len(items) == 1, 'Expected exactly one update.'
enclosure = items[0].find('enclosure')
assert enclosure is not None and enclosure.get('{http://www.andymatuschak.org/xml-namespaces/sparkle}edSignature'), 'Unsigned update.'
assert int(enclosure.get('length', '0')) == next(Path('dist/updates').glob('*.zip')).stat().st_size, 'Archive length mismatch.'
archive = next(Path('dist/updates').glob('*.zip'))
public_key = json.loads(Path('Config/updates.json').read_text())['publicEDKey']
subprocess.run(['xcrun', 'swift', 'Tests/UpdateSignatureChecks.swift', str(archive),
                enclosure.get('{http://www.andymatuschak.org/xml-namespaces/sparkle}edSignature'), public_key], check=True)
print('Signed update and appcast ready in dist/updates.')
PY
