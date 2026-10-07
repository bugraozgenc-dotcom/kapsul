#!/bin/zsh
set -eu

if (( $# != 1 )); then
  print -u2 -- "Usage: $0 <approved-icon.png>"
  exit 1
fi

icon_source="${1:A}"
if [[ ! -f "$icon_source" ]]; then
  print -u2 -- "Icon PNG does not exist: $icon_source"
  exit 1
fi

project_dir="${0:A:h:h}"
cd "$project_dir"

source_format="$(/usr/bin/sips -g format "$icon_source" | /usr/bin/awk '/^[[:space:]]*format:/ {print $2}')"
if [[ "$source_format" != "png" ]]; then
  print -u2 -- "The input must be a PNG image."
  exit 1
fi

source_width="$(/usr/bin/sips -g pixelWidth "$icon_source" | /usr/bin/awk '/^[[:space:]]*pixelWidth:/ {print $2}')"
source_height="$(/usr/bin/sips -g pixelHeight "$icon_source" | /usr/bin/awk '/^[[:space:]]*pixelHeight:/ {print $2}')"
if [[ "$source_width" != "$source_height" || "$source_width" == "0" || -z "$source_width" ]]; then
  print -u2 -- "The input PNG must be square."
  exit 1
fi

icon_work_dir="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/kapsul-icon.XXXXXX")"
trap '/bin/rm -rf -- "$icon_work_dir"' EXIT

iconset_dir="$icon_work_dir/Kapsul.iconset"
/bin/mkdir -p "$iconset_dir"

for logical_size in 16 32 128 256 512; do
  /usr/bin/sips -z "$logical_size" "$logical_size" "$icon_source" \
    --out "$iconset_dir/icon_${logical_size}x${logical_size}.png" >/dev/null
  pixel_size=$(( logical_size * 2 ))
  /usr/bin/sips -z "$pixel_size" "$pixel_size" "$icon_source" \
    --out "$iconset_dir/icon_${logical_size}x${logical_size}@2x.png" >/dev/null
done

/usr/bin/iconutil -c icns "$iconset_dir" -o "$icon_work_dir/Kapsul.icns"
/bin/cp "$icon_source" "$icon_work_dir/app-icon.png"

# Publish only after every icon rendition and the ICNS have succeeded.
/bin/mkdir -p Assets/Branding Sources/CopyGlass/Resources
/bin/cp "$icon_work_dir/Kapsul.icns" Assets/Branding/Kapsul.icns
/bin/cp "$icon_work_dir/app-icon.png" Sources/CopyGlass/Resources/app-icon.png

print -- "Prepared Assets/Branding/Kapsul.icns and Sources/CopyGlass/Resources/app-icon.png"
