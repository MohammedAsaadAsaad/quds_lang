#!/usr/bin/env bash
# Installs the Quds CLI and the editor extension on Linux.
# Dart is installed from Google's signed apt repository when it is missing
# or older than 3.13.0. Package signatures stay enabled. Apt is answered
# with -y, so the script does not stop for a license prompt. The Dart SDK
# license is BSD-3-Clause.
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
extension_dir="$repo_dir/editors/vscode"
min_dart="3.13.0"
skip_dart=0
skip_cli=0
skip_editor=0

for arg in "$@"; do
  case "$arg" in
    --skip-dart) skip_dart=1 ;;
    --skip-cli) skip_cli=1 ;;
    --skip-editor) skip_editor=1 ;;
    *)
      echo "Usage: bash install.sh [--skip-dart] [--skip-cli] [--skip-editor]" >&2
      exit 64
      ;;
  esac
done

say() {
  printf '%s\n' "$1"
}

version_ge() {
  printf '%s\n%s\n' "$2" "$1" | sort -C -V
}

dart_version() {
  dart --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1
}

have_dart() {
  command -v dart >/dev/null 2>&1 && version_ge "$(dart_version)" "$min_dart"
}

install_dart() {
  if ! command -v apt-get >/dev/null 2>&1; then
    say "Dart ${min_dart} أو أحدث غير موجود، وهذا النظام بلا apt-get."
    say "ثبّت Dart من https://dart.dev/get-dart ثم أعد تشغيل install.sh."
    exit 1
  fi
  if ! command -v sudo >/dev/null 2>&1; then
    say "تثبيت Dart يحتاج sudo، والأمر غير موجود."
    exit 1
  fi
  say "تثبيت Dart من المستودع الرسمي الموقع. قد يُطلب كلمة مرور sudo مرة واحدة."
  sudo -v
  export DEBIAN_FRONTEND=noninteractive
  sudo apt-get update
  sudo apt-get install -y ca-certificates curl gnupg
  local arch key
  arch="$(dpkg --print-architecture)"
  case "$arch" in
    amd64 | arm64 | armhf) ;;
    *)
      say "معمارية $arch ليست في مستودع Dart الرسمي."
      exit 1
      ;;
  esac
  key="$(mktemp)"
  curl -fsSL https://dl-ssl.google.com/linux/linux_signing_key.pub | gpg --dearmor >"$key"
  sudo install -m 644 "$key" /usr/share/keyrings/dart.gpg
  rm -f "$key"
  echo "deb [signed-by=/usr/share/keyrings/dart.gpg arch=${arch}] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main" |
    sudo tee /etc/apt/sources.list.d/dart_stable.list >/dev/null
  sudo apt-get update
  sudo apt-get install -y dart
  hash -r
  if ! have_dart; then
    say "Dart ما زال أقدم من ${min_dart} بعد التثبيت."
    exit 1
  fi
}

persist_path() {
  local file snippet
  snippet='export PATH="$PATH:$HOME/.pub-cache/bin"'
  for file in "$HOME/.bashrc" "$HOME/.profile"; do
    touch "$file"
    if ! grep -q '.pub-cache/bin' "$file"; then
      printf '\n# Quds language CLI\n%s\n' "$snippet" >>"$file"
    fi
  done
  export PATH="$PATH:$HOME/.pub-cache/bin"
}

install_cli() {
  say "تفعيل أمر quds من هذا المجلد."
  (cd "$repo_dir" && dart pub get --enforce-lockfile)
  dart pub global activate --source path "$repo_dir"
  persist_path
  hash -r
  local check dir
  check="$(mktemp -d)"
  cp "$repo_dir/examples/sum.quds" "$check/sum.quds"
  (
    cd "$check"
    quds build sum.quds
    dart run .dart_tool/quds/out/sum.dart
  )
  rm -rf "$check"
}

extension_id() {
  python3 - "$extension_dir/package.json" <<'PY'
import json, sys
package = json.load(open(sys.argv[1], encoding="utf-8"))
print(f"{package['publisher']}.{package['name']}-{package['version']}")
PY
}

stage_extension() {
  local dest id
  id="$(extension_id)"
  dest="$1/$id"
  rm -rf "$dest"
  mkdir -p "$dest/syntaxes" "$dest/icons"
  cp "$extension_dir/package.json" "$extension_dir/extension.js" \
    "$extension_dir/language-configuration.json" "$extension_dir/README.md" \
    "$dest/"
  cp "$extension_dir/syntaxes/quds.tmLanguage.json" "$dest/syntaxes/"
  cp "$extension_dir/icons/quds.png" "$dest/icons/"
  say "رُكّبت الإضافة في $dest"
}

install_editor() {
  local id vsix editors=()
  id="$(extension_id)"
  vsix="$(mktemp --suffix=.vsix)"
  python3 - "$extension_dir" "$vsix" <<'PY'
import json, pathlib, sys, zipfile
source = pathlib.Path(sys.argv[1])
destination = pathlib.Path(sys.argv[2])
package = json.loads((source / "package.json").read_text(encoding="utf-8"))
manifest = f"""<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011">
  <Metadata>
    <Identity Language="en-US" Id="{package["name"]}" Version="{package["version"]}" Publisher="{package["publisher"]}"/>
    <DisplayName>{package["displayName"]}</DisplayName>
    <Description xml:space="preserve">{package["description"]}</Description>
  </Metadata>
  <Installation>
    <InstallationTarget Id="Microsoft.VisualStudio.Code"/>
  </Installation>
  <Dependencies/>
  <Assets>
    <Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true"/>
  </Assets>
</PackageManifest>
"""
types = """<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension=".json" ContentType="application/json"/>
  <Default Extension=".js" ContentType="application/javascript"/>
  <Default Extension=".md" ContentType="text/markdown"/>
  <Default Extension=".png" ContentType="image/png"/>
  <Default Extension=".vsixmanifest" ContentType="text/xml"/>
</Types>
"""
files = [
    "package.json",
    "extension.js",
    "language-configuration.json",
    "README.md",
    "syntaxes/quds.tmLanguage.json",
    "icons/quds.png",
]
with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_DEFLATED) as archive:
    archive.writestr("[Content_Types].xml", types)
    archive.writestr("extension.vsixmanifest", manifest)
    for name in files:
        archive.write(source / name, f"extension/{name}")
PY
  command -v code >/dev/null 2>&1 && editors+=("code")
  command -v cursor >/dev/null 2>&1 && editors+=("cursor")
  if [[ ${#editors[@]} -gt 0 ]]; then
    local editor
    for editor in "${editors[@]}"; do
      say "تثبيت الإضافة عبر $editor."
      "$editor" --install-extension "$vsix" --force
    done
  else
    say "أمر code غير موجود. نسخ الإضافة إلى مجلدات VS Code و Cursor."
    stage_extension "$HOME/.vscode/extensions"
    stage_extension "$HOME/.cursor/extensions"
  fi
  rm -f "$vsix"
  say "معرّف الإضافة: $id"
}

if [[ "$skip_dart" -eq 0 ]]; then
  if have_dart; then
    say "Dart $(dart_version) موجود."
  else
    install_dart
  fi
fi

if [[ "$skip_cli" -eq 0 ]]; then
  install_cli
fi

if [[ "$skip_editor" -eq 0 ]]; then
  install_editor
fi

say "اكتمل التثبيت."
if [[ "$skip_cli" -eq 0 ]]; then
  say "افتح طرفية جديدة ثم: quds build ملف.quds"
fi
if [[ "$skip_editor" -eq 0 ]]; then
  say "أعد تحميل VS Code أو Cursor وافتح ملفاً بامتداد .quds."
fi
