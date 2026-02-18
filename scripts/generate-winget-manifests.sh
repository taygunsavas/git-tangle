#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
REPO="${2:-}"
SHA256="${3:-}"
OUT_ROOT="${4:-}"

if [[ -z "$VERSION" || -z "$REPO" || -z "$SHA256" || -z "$OUT_ROOT" ]]; then
  echo "usage: generate-winget-manifests.sh <version> <repo> <sha256> <output-root>" >&2
  exit 1
fi

PACKAGE_ID="taygunsavas.git-tangle"
PUBLISHER="taygunsavas"
PACKAGE_NAME="Git Tangle"
MONIKER="git-tangle"
SHORT_DESC="A branching workflow tool that untangles your repo."
MANIFEST_VERSION="1.10.0"
PACKAGE_LOCALE="en-US"
INSTALLER_URL="https://github.com/${REPO}/releases/download/${VERSION}/git-tangle_${VERSION}_windows_x64.zip"
MANIFEST_DIR="$OUT_ROOT/manifests/t/taygunsavas/git-tangle/$VERSION"

mkdir -p "$MANIFEST_DIR"

cat > "$MANIFEST_DIR/${PACKAGE_ID}.yaml" <<EOF
# yaml-language-server: \$schema=https://aka.ms/winget-manifest.version.${MANIFEST_VERSION}.schema.json
PackageIdentifier: ${PACKAGE_ID}
PackageVersion: ${VERSION}
DefaultLocale: ${PACKAGE_LOCALE}
ManifestType: version
ManifestVersion: ${MANIFEST_VERSION}
EOF

cat > "$MANIFEST_DIR/${PACKAGE_ID}.installer.yaml" <<EOF
# yaml-language-server: \$schema=https://aka.ms/winget-manifest.installer.${MANIFEST_VERSION}.schema.json
PackageIdentifier: ${PACKAGE_ID}
PackageVersion: ${VERSION}
InstallerType: zip
NestedInstallerType: portable
NestedInstallerFiles:
  - RelativeFilePath: git-tangle.cmd
    PortableCommandAlias: git-tangle
Dependencies:
  PackageDependencies:
    - PackageIdentifier: Git.Git
Installers:
  - Architecture: x64
    InstallerUrl: ${INSTALLER_URL}
    InstallerSha256: ${SHA256}
ManifestType: installer
ManifestVersion: ${MANIFEST_VERSION}
EOF

cat > "$MANIFEST_DIR/${PACKAGE_ID}.locale.${PACKAGE_LOCALE}.yaml" <<EOF
# yaml-language-server: \$schema=https://aka.ms/winget-manifest.defaultLocale.${MANIFEST_VERSION}.schema.json
PackageIdentifier: ${PACKAGE_ID}
PackageVersion: ${VERSION}
PackageLocale: ${PACKAGE_LOCALE}
Publisher: ${PUBLISHER}
PackageName: ${PACKAGE_NAME}
Moniker: ${MONIKER}
License: MIT
ShortDescription: ${SHORT_DESC}
ManifestType: defaultLocale
ManifestVersion: ${MANIFEST_VERSION}
EOF

echo "Generated WinGet manifests in $MANIFEST_DIR"
