#!/usr/bin/env bash
set -euo pipefail

ROM_ROOT="${1:-$PWD}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$SCRIPT_DIR/lineage-a17-repro-20260925-final"
SOURCE_MANIFEST="$PACKAGE_DIR/manifest/eqe-a17.xml"
TARGET_MANIFEST="$ROM_ROOT/.repo/local_manifests/eqe-a17.xml"

if ! command -v git-lfs >/dev/null 2>&1; then
    echo "ERROR: se necesita git-lfs antes de sincronizar el Vendor A17." >&2
    exit 1
fi
git lfs version >/dev/null

if [[ ! -d "$ROM_ROOT/.repo" ]]; then
    echo "ERROR: $ROM_ROOT no parece ser una fuente inicializada con repo." >&2
    exit 1
fi

mkdir -p "$ROM_ROOT/.repo/local_manifests"

if [[ -e "$TARGET_MANIFEST" ]]; then
    if cmp -s "$SOURCE_MANIFEST" "$TARGET_MANIFEST"; then
        echo "El manifiesto ya está instalado y coincide exactamente."
        exit 0
    fi

    echo "ERROR: ya existe un manifiesto distinto en $TARGET_MANIFEST" >&2
    exit 1
fi

cp "$SOURCE_MANIFEST" "$TARGET_MANIFEST"
echo "Manifiesto A17 instalado en $TARGET_MANIFEST"
echo "Ahora se puede ejecutar repo sync para obtener las revisiones fijadas."
echo "El script aplicar-compatibilidad.sh descargará y verificará los objetos Git LFS."
