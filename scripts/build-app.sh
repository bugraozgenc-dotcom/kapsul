#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

usage() {
  cat <<'EOF'
Usage: scripts/build-app.sh [--release] [--universal]
       [--configuration debug|release] [--arch native|arm64|x86_64|universal]

Defaults: debug, native architecture, ad hoc signing.
Environment: COPYGLASS_BUILD_DIR, COPYGLASS_CONFIGURATION, COPYGLASS_ARCH,
             COPYGLASS_VERSION, COPYGLASS_BUILD_NUMBER, CODE_SIGN_IDENTITY.
CODE_SIGN_IDENTITY must name a Developer ID Application certificate (or its hash)
to enable distribution signing, hardened runtime, and a secure timestamp.
EOF
}

copyglass_configuration="${COPYGLASS_CONFIGURATION:-debug}"
copyglass_arch="${COPYGLASS_ARCH:-native}"
while (( $# )); do
  case "$1" in
    --release) copyglass_configuration=release; shift ;;
    --universal) copyglass_arch=universal; shift ;;
    --configuration|--arch)
      if (( $# < 2 )); then usage >&2; exit 2; fi
      if [[ "$1" == --configuration ]]; then copyglass_configuration="$2"; else copyglass_arch="$2"; fi
      shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) print -u2 -- "Unknown option: $1"; usage >&2; exit 2 ;;
  esac
done
case "$copyglass_configuration" in debug|release) ;; *) print -u2 'Configuration must be debug or release.'; exit 2 ;; esac
case "$copyglass_arch" in native|arm64|x86_64|universal) ;; *) print -u2 'Architecture must be native, arm64, x86_64, or universal.'; exit 2 ;; esac

# Keep compilation and signing out of cloud-synced folders. Copying files below
# deliberately omits Finder/resource-fork attributes that invalidate signatures.
copyglass_build_dir="${COPYGLASS_BUILD_DIR:-$HOME/Library/Caches/CopyGlass/build}"
typeset -a copyglass_build_args
copyglass_build_args=(--scratch-path "$copyglass_build_dir" --configuration "$copyglass_configuration")
case "$copyglass_arch" in
  universal) copyglass_build_args+=(--arch arm64 --arch x86_64) ;;
  arm64|x86_64) copyglass_build_args+=(--arch "$copyglass_arch") ;;
esac
swift build "${copyglass_build_args[@]}"
copyglass_bin_dir="$(swift build "${copyglass_build_args[@]}" --show-bin-path)"
python3 - "$copyglass_bin_dir" "$copyglass_build_dir" "$copyglass_configuration" "$copyglass_arch" <<'PY'
import datetime, json, os, platform, plistlib, re, shutil, subprocess, sys, tempfile
from pathlib import Path

source = Path(sys.argv[1])
build_root = Path(sys.argv[2]).expanduser().resolve()
configuration, requested_arch = sys.argv[3:5]
version = os.environ.get('COPYGLASS_VERSION', '0.6.0')
build_number = os.environ.get('COPYGLASS_BUILD_NUMBER', '6')
if not re.fullmatch(r'\d+\.\d+\.\d+', version) or not re.fullmatch(r'\d+', build_number):
    raise SystemExit('COPYGLASS_VERSION must be x.y.z; COPYGLASS_BUILD_NUMBER must be an integer.')
identity = os.environ.get('CODE_SIGN_IDENTITY', '').strip() or '-'
developer_id = False
if identity != '-':
    identities = subprocess.run(['security', 'find-identity', '-v', '-p', 'codesigning'],
                               check=True, text=True, capture_output=True).stdout
    matches = re.findall(r'\b([0-9A-Fa-f]{40})\s+"([^"]+)"', identities)
    selected = [(fingerprint, name) for fingerprint, name in matches
                if identity.lower() == fingerprint.lower() or identity == name]
    if len(selected) != 1 or not selected[0][1].startswith('Developer ID Application:'):
        raise SystemExit('CODE_SIGN_IDENTITY must select an available Developer ID Application certificate.')
    identity = selected[0][0]
    developer_id = True

architectures = subprocess.run(['lipo', '-archs', str(source/'CopyGlass')], check=True,
                               text=True, capture_output=True).stdout.split()
expected_architectures = {'arm64', 'x86_64'} if requested_arch == 'universal' else {
    platform.machine() if requested_arch == 'native' else requested_arch
}
if set(architectures) != expected_architectures:
    raise SystemExit(f'Architecture mismatch: expected {sorted(expected_architectures)}, got {architectures}.')

stage_root = Path(tempfile.mkdtemp(prefix='app-stage-', dir=build_root))
stage_app = stage_root/'Kapsül.app'
dist = Path('dist').resolve()
destination = dist/'Kapsül.app'
backup = None
try:
    contents = stage_app/'Contents'
    (contents/'MacOS').mkdir(parents=True)
    (contents/'Resources').mkdir()
    executable = contents/'MacOS/CopyGlass'
    shutil.copyfile(source/'CopyGlass', executable)
    executable.chmod(0o755)
    shutil.copytree(source/'CopyGlass_CopyGlass.bundle', contents/'Resources/CopyGlass_CopyGlass.bundle',
                    copy_function=shutil.copyfile)
    updates = json.loads(Path('Config/updates.json').read_text())
    frameworks = list((build_root/'artifacts/sparkle/Sparkle').rglob('macos-arm64_x86_64/Sparkle.framework'))
    if len(frameworks) != 1:
        raise SystemExit('Expected one universal Sparkle.framework in SwiftPM artifacts.')
    (contents/'Frameworks').mkdir()
    framework = contents/'Frameworks/Sparkle.framework'
    def copy_code(source, destination):
        shutil.copyfile(source, destination)
        shutil.copymode(source, destination)
        return destination
    shutil.copytree(frameworks[0], framework, symlinks=True, copy_function=copy_code)
    with (contents/'Info.plist').open('wb') as f:
        plistlib.dump({'CFBundleExecutable':'CopyGlass','CFBundleIdentifier':'local.copyglass.app',
                      'CFBundleName':'Kapsül','CFBundleDisplayName':'Kapsül','CFBundleIconFile':'Kapsul.icns',
                      'CFBundlePackageType':'APPL','CFBundleShortVersionString':version,
                      'CFBundleVersion':build_number,'CFBundleDevelopmentRegion':'tr',
                      'CFBundleLocalizations':['tr','en','fr','de','es'],
                      'LSMinimumSystemVersion':'14.0','NSHighResolutionCapable':True,
                      'SUFeedURL':updates['feedURL'], 'SUPublicEDKey':updates['publicEDKey'],
                      'SUEnableAutomaticChecks':False, 'SUAutomaticallyUpdate':False,
                      'SUVerifyUpdateBeforeExtraction':True}, f)
    shutil.copyfile('Assets/Branding/Kapsul.icns', contents/'Resources/Kapsul.icns')

    sign_args = ['codesign', '--force', '--sign', identity]
    if developer_id:
        sign_args += ['--options', 'runtime', '--timestamp']
    # Sign nested Sparkle code inside-out, preserving framework symlinks.
    nested = [path for path in framework.rglob('*') if not path.is_symlink()
              and (path.suffix in {'.xpc', '.app'} or path.name in {'Autoupdate', 'Sparkle'})]
    for path in sorted(nested, key=lambda path: len(path.parts), reverse=True):
        if path.is_file() or path.suffix in {'.xpc', '.app'}:
            subprocess.run(sign_args + [str(path)], check=True)
    subprocess.run(sign_args + [str(framework)], check=True)
    subprocess.run(sign_args + [str(executable)], check=True)
    subprocess.run(sign_args + [str(stage_app)], check=True)
    subprocess.run(['codesign', '--verify', '--deep', '--strict', '--verbose=2', str(stage_app)], check=True)
    subprocess.run(['plutil', '-lint', str(contents/'Info.plist')], check=True)

    manifest = {
        'app': 'Kapsül.app', 'executable': 'CopyGlass', 'bundleIdentifier': 'local.copyglass.app',
        'version': version, 'buildNumber': build_number, 'configuration': configuration,
        'architectures': sorted(architectures), 'minimumMacOS': '14.0',
        'signing': 'developer-id' if developer_id else 'ad-hoc',
        'hardenedRuntime': developer_id, 'notarized': False,
        'builtAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    }
    manifest_path = stage_root/'app-build-manifest.json'
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    dist.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        backup = dist/f'.Kapsül.app-backup-{stage_root.name}'
        os.rename(destination, backup)
    try:
        os.rename(stage_app, destination)
    except BaseException:
        if backup is not None:
            os.rename(backup, destination)
            backup = None
        raise
    os.replace(manifest_path, dist/'app-build-manifest.json')
    if backup is not None:
        shutil.rmtree(backup)
        backup = None
    print(f'Hazır: dist/Kapsül.app ({configuration}; {", ".join(sorted(architectures))}; {manifest["signing"]})')
    print('Manifest: dist/app-build-manifest.json')
finally:
    shutil.rmtree(stage_root, ignore_errors=True)
PY
