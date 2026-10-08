#!/bin/zsh
# Package an already-built app; the original bundle is never modified.
set -eu
set -o pipefail
cd "$(dirname "$0")/.."

if [[ $# -gt 1 || "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  print 'Usage: scripts/package-dmg.sh [path/to/Kapsül.app]'
  print 'Defaults: app=dist/Kapsül.app, output=dist'
  print 'Environment: KAPSUL_APP_PATH, KAPSUL_DMG_DIR, KAPSUL_PACKAGE_CACHE_DIR'
  exit 0
fi

kapsul_app_path="${1:-${KAPSUL_APP_PATH:-dist/Kapsül.app}}"
kapsul_output_dir="${KAPSUL_DMG_DIR:-dist}"
kapsul_cache_dir="${KAPSUL_PACKAGE_CACHE_DIR:-$HOME/Library/Caches/Kapsul/packaging}"
if [[ ! -d "$kapsul_app_path/Contents" ]]; then
  print -u2 "App bundle not found: $kapsul_app_path"
  print -u2 'Build the app first with scripts/build-app.sh.'
  exit 1
fi

# A valid ad hoc signature is sufficient for packaging, but is not a Developer ID
# signature or Apple notarization. The installer text states that distinction.
# Verify the clean staged copy below: synced folders can attach Finder metadata
# to an otherwise valid signed bundle after the build has completed.
kapsul_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$kapsul_app_path/Contents/Info.plist")"
kapsul_executable="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$kapsul_app_path/Contents/Info.plist")"
if [[ ! "$kapsul_version" =~ '^[0-9]+([.][0-9]+)*$' || "$kapsul_executable" == */* ]]; then
  print -u2 'Invalid app version or executable name in Info.plist.'
  exit 1
fi
kapsul_archs="$(/usr/bin/lipo -archs "$kapsul_app_path/Contents/MacOS/$kapsul_executable")"
if [[ " $kapsul_archs " == *' arm64 '* && " $kapsul_archs " == *' x86_64 '* ]]; then
  kapsul_arch_label='universal'
elif [[ "$kapsul_archs" == 'arm64' || "$kapsul_archs" == 'x86_64' ]]; then
  kapsul_arch_label="$kapsul_archs"
else
  print -u2 "Unsupported app architectures: $kapsul_archs"
  exit 1
fi

kapsul_signature_info="$(/usr/bin/codesign -d --verbose=2 "$kapsul_app_path" 2>&1)"
kapsul_signing_status='ad-hoc'
if [[ "$kapsul_signature_info" == *'Authority=Developer ID Application:'* ]]; then
  kapsul_signing_status='developer-id'
  if /usr/bin/xcrun stapler validate "$kapsul_app_path" >/dev/null 2>&1; then
    kapsul_signing_status='notarized'
  fi
elif [[ "$kapsul_signature_info" != *'Signature=adhoc'* ]]; then
  kapsul_signing_status='other-signature'
fi

mkdir -p "$kapsul_output_dir" "$kapsul_cache_dir"
kapsul_work_dir="$(mktemp -d "$kapsul_cache_dir/dmg.XXXXXX")"
kapsul_stage_dir="$kapsul_work_dir/stage"
kapsul_mount_dir="$kapsul_work_dir/mount"
kapsul_attached=0
cleanup() {
  # Never recursively remove a directory while the disk image is mounted there.
  if [[ "$kapsul_attached" == 1 ]]; then
    if ! /usr/bin/hdiutil detach "$kapsul_mount_dir" >/dev/null 2>&1; then
      print -u2 "Could not detach the image; temporary files retained at $kapsul_work_dir"
      return
    fi
  fi
  rm -rf "$kapsul_work_dir"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir -p "$kapsul_stage_dir/.background" "$kapsul_mount_dir"
# Finder metadata is generated with pinned, build-only Python dependencies.
kapsul_python="$kapsul_cache_dir/python/bin/python"
if [[ ! -x "$kapsul_python" ]]; then
  python3 -m venv "$kapsul_cache_dir/python"
fi
if ! "$kapsul_python" -c 'import ds_store, mac_alias; from importlib.metadata import version; assert version("ds-store") == "1.3.1"; assert version("mac-alias") == "2.2.2"' >/dev/null 2>&1; then
  "$kapsul_python" -m pip install ds-store==1.3.1 mac-alias==2.2.2
fi
xcrun swift scripts/render-dmg-background.swift "$kapsul_stage_dir/.background/background.png"

python3 - "$kapsul_app_path" "$kapsul_stage_dir" "$kapsul_version" "$kapsul_signing_status" <<'PY'
import os
import shutil
import sys
from pathlib import Path

app_path, stage_path, version, signing_status = sys.argv[1:]
stage = Path(stage_path)

def copy_without_xattrs(source, destination):
    shutil.copyfile(source, destination)
    shutil.copymode(source, destination)
    return destination

shutil.copytree(app_path, stage / 'Kapsül.app', symlinks=True,
                copy_function=copy_without_xattrs)
os.symlink('/Applications', stage / 'Applications')

signing = {
    'ad-hoc': (
        'Bu sürüm ad hoc imzalıdır; Developer ID imzası ve Apple noter onayı yoktur. '
        'İnternetten indirilen uygulamada macOS güvenlik uyarısı gösterebilir. '
        'Kaynağa güveniyorsanız açmayı denedikten sonra Sistem Ayarları > '
        'Gizlilik ve Güvenlik bölümündeki Yine de Aç seçeneğini kullanabilirsiniz.',
        'This build is ad hoc signed, without a Developer ID signature or Apple '
        'notarization. macOS may show a security warning for downloads. If you '
        'trust the source, try opening the app, then use Open Anyway in System '
        'Settings > Privacy & Security.'),
    'developer-id': (
        'Bu sürüm Developer ID ile imzalıdır. Bu pakette Apple noter onayını '
        'doğrulayan bir bilet bulunamadı; macOS güvenlik uyarısı gösterebilir.',
        'This build is Developer ID signed. No stapled Apple notarization '
        'ticket was confirmed for this bundle; macOS may show a security warning.'),
    'notarized': (
        'Bu sürüm Developer ID ile imzalıdır; Apple noter onayı bileti doğrulandı.',
        'This build is Developer ID signed with a verified stapled Apple '
        'notarization ticket.'),
    'other-signature': (
        'Uygulamanın kod imzası doğrulandı; Developer ID imzası veya Apple noter '
        'onayı doğrulanmadı. macOS güvenlik uyarısı gösterebilir.',
        'The code signature was verified, but a Developer ID signature and '
        'Apple notarization were not confirmed. macOS may show a security warning.')
}[signing_status]
readme = f'''Kapsül {version}

KURULUM
1. Kapsül.app dosyasını bu penceredeki Applications klasörüne sürükleyin.
2. Uygulamalar klasöründen Kapsül'ü açın.
3. Kurulum tamamlanınca Kapsül disk görüntüsünü çıkarın.

macOS 14 veya daha yeni bir sürüm gerekir.
{signing[0]}

INSTALLATION
1. Drag Kapsül.app to the Applications folder in this window.
2. Open Kapsül from Applications.
3. Eject the Kapsül disk image after installation.

Requires macOS 14 or later.
{signing[1]}
'''
(stage / '.background' / 'Kurulum - Installation.txt').write_text(readme, encoding='utf-8')
PY

# Finder/iCloud metadata from the source must not invalidate the copied bundle.
/usr/bin/xattr -cr "$kapsul_stage_dir/Kapsül.app"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$kapsul_stage_dir/Kapsül.app"
kapsul_filename="Kapsul-$kapsul_version-$kapsul_arch_label.dmg"
kapsul_temp_dmg="$kapsul_work_dir/$kapsul_filename"
kapsul_rw_dmg="$kapsul_work_dir/layout.dmg"
/usr/bin/hdiutil create -srcfolder "$kapsul_stage_dir" -volname 'Kapsül Kurulum' \
  -fs HFS+ -format UDRW -nospotlight "$kapsul_rw_dmg"
# Set this before attaching so an interrupted attach also retains the mount safely.
kapsul_attached=1
/usr/bin/hdiutil attach -nobrowse -noautoopen -mountpoint "$kapsul_mount_dir" "$kapsul_rw_dmg"
[[ -d "$kapsul_mount_dir/Kapsül.app/Contents" ]]
[[ -L "$kapsul_mount_dir/Applications" ]]
[[ "$(readlink "$kapsul_mount_dir/Applications")" == '/Applications' ]]
[[ -f "$kapsul_mount_dir/.background/Kurulum - Installation.txt" ]]
"$kapsul_python" scripts/style-dmg.py "$kapsul_mount_dir"
[[ -f "$kapsul_mount_dir/.DS_Store" ]]
/usr/bin/codesign --verify --deep --strict --verbose=2 "$kapsul_mount_dir/Kapsül.app"
/usr/bin/hdiutil detach "$kapsul_mount_dir"
kapsul_attached=0
/usr/bin/hdiutil convert "$kapsul_rw_dmg" -format UDZO -imagekey zlib-level=9 -o "$kapsul_temp_dmg"
/usr/bin/hdiutil verify "$kapsul_temp_dmg"

mv -f "$kapsul_temp_dmg" "$kapsul_output_dir/$kapsul_filename"
(cd "$kapsul_output_dir" && /usr/bin/shasum -a 256 "$kapsul_filename" > "$kapsul_filename.sha256")
print "DMG: $kapsul_output_dir/$kapsul_filename"
print "SHA-256: $kapsul_output_dir/$kapsul_filename.sha256"
print "Architectures: $kapsul_archs; signing: $kapsul_signing_status"
