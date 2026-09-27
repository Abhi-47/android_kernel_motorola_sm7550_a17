#!/usr/bin/env bash
set -euo pipefail

ROM_ROOT="${1:-$PWD}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$SCRIPT_DIR/lineage-a17-repro-20260925-final"

FRAMEWORKS_AV_BASE="5f059f6bd2ffc720423b2f4359696a750970a86b"
FRAMEWORKS_NATIVE_BASE="46018f54b42489de960c62c3db9de131abce43ea"
OPENEUICC_BASE="49e498d4cb331d285e084cc3ab0629ae74ff86fc"
A17_TAG="a17-ready-v4"
ZXING_AAR_SHA256="4ab03353127c34e55cbb80fbc9a34031decbcfb1ec5e8f991944d2d494621a33"
ZXING_CORE_SHA256="acfa30338c26267b6cab665509c2251bb96e8350bfcad89d59b949ba77011f8d"
MOTCAMERA3AI_SHA256="239e7a4974a04dd7e7d76e03f790e827e64aae239d5bc90c351f200e76d38747"
MOTCAMERA4_SHA256="58a67ca09e0435b260c243756ab246ab4344034ee55b7855180e901e5810e5cc"
MODEM_SHA256="cbdafb4d6e39dab64e8e8d4c44c038dfb6926c35429f86904b92da7fc5869fe6"

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

check_revision() {
    local repo_path="$1"
    local expected="$2"
    local actual

    [[ -d "$ROM_ROOT/$repo_path/.git" ]] || fail "falta el repositorio $repo_path"
    actual="$(git -C "$ROM_ROOT/$repo_path" rev-parse HEAD)"
    [[ "$actual" == "$expected" ]] ||
        fail "$repo_path está en $actual; se esperaba $expected"
}

check_tag() {
    local repo_path="$1"
    local expected_tag="$2"
    local actual tagged

    [[ -d "$ROM_ROOT/$repo_path/.git" ]] || fail "falta el repositorio $repo_path"
    actual="$(git -C "$ROM_ROOT/$repo_path" rev-parse HEAD)"
    tagged="$(git -C "$ROM_ROOT/$repo_path" rev-parse "refs/tags/$expected_tag^{commit}" 2>/dev/null || true)"
    [[ -n "$tagged" && "$actual" == "$tagged" ]] ||
        fail "$repo_path no corresponde a la versión $expected_tag"
}

[[ -f "$PACKAGE_DIR/SHA256SUMS" ]] || fail "no se encontró el paquete reproducible"
(
    cd "$PACKAGE_DIR"
    sha256sum -c SHA256SUMS
)

check_revision frameworks/av "$FRAMEWORKS_AV_BASE"
check_revision frameworks/native "$FRAMEWORKS_NATIVE_BASE"
check_revision packages/apps/OpenEUICC "$OPENEUICC_BASE"
check_tag kernel/motorola/sm7550 "$A17_TAG"
check_tag kernel/motorola/sm7550-modules "$A17_TAG"
check_tag vendor/motorola/eqe "$A17_TAG"
check_tag vendor/qcom/wfd "$A17_TAG"

[[ -z "$(git -C "$ROM_ROOT/frameworks/av" status --porcelain -- media/libheif)" ]] ||
    fail "frameworks/av media/libheif ya contiene cambios"
[[ -z "$(git -C "$ROM_ROOT/frameworks/native" status --porcelain -- libs/gui/SurfaceComposerClient.cpp libs/gui/include/gui/SurfaceComposerClient.h)" ]] ||
    fail "frameworks/native ya contiene cambios en SurfaceComposerClient"
[[ -z "$(git -C "$ROM_ROOT/kernel/motorola/sm7550" status --porcelain)" ]] ||
    fail "el kernel principal no está limpio"
[[ -z "$(git -C "$ROM_ROOT/kernel/motorola/sm7550-modules" status --porcelain)" ]] ||
    fail "los módulos del kernel no están limpios"
[[ -z "$(git -C "$ROM_ROOT/vendor/motorola/eqe" status --porcelain)" ]] ||
    fail "el vendor Motorola A17 no está limpio"
[[ -z "$(git -C "$ROM_ROOT/vendor/qcom/wfd" status --porcelain)" ]] ||
    fail "el vendor Qualcomm WFD A17 no está limpio"
[[ ! -e "$ROM_ROOT/packages/apps/OpenEUICC/app-deps/maven" ]] ||
    fail "OpenEUICC/app-deps/maven ya existe"

command -v git-lfs >/dev/null 2>&1 ||
    fail "se necesita git-lfs para descargar los archivos grandes del Vendor A17"
git lfs version >/dev/null || fail "git-lfs no funciona correctamente"
git -C "$ROM_ROOT/vendor/motorola/eqe" lfs pull
git -C "$ROM_ROOT/vendor/motorola/eqe" lfs fsck

[[ "$(sha256sum "$ROM_ROOT/vendor/motorola/eqe/proprietary/product/app/MotCamera3AI/MotCamera3AI.apk" | awk '{print $1}')" == "$MOTCAMERA3AI_SHA256" ]] ||
    fail "MotCamera3AI no conserva la huella esperada"
[[ "$(sha256sum "$ROM_ROOT/vendor/motorola/eqe/proprietary/product/priv-app/MotCamera4/MotCamera4.apk" | awk '{print $1}')" == "$MOTCAMERA4_SHA256" ]] ||
    fail "MotCamera4 no conserva la huella esperada"
[[ "$(sha256sum "$ROM_ROOT/vendor/motorola/eqe/radio/modem.img" | awk '{print $1}')" == "$MODEM_SHA256" ]] ||
    fail "modem.img no conserva la huella esperada"

git -C "$ROM_ROOT/frameworks/av" apply --check \
    "$PACKAGE_DIR/patches/frameworks-av-libheif.patch"
git -C "$ROM_ROOT/frameworks/native" apply --check \
    "$PACKAGE_DIR/patches/frameworks-native-a16-abi.patch"

git -C "$ROM_ROOT/frameworks/av" apply \
    "$PACKAGE_DIR/patches/frameworks-av-libheif.patch"
git -C "$ROM_ROOT/frameworks/native" apply \
    "$PACKAGE_DIR/patches/frameworks-native-a16-abi.patch"

mkdir -p "$ROM_ROOT/packages/apps/OpenEUICC/app-deps/maven"
cp "$PACKAGE_DIR/files/packages/apps/OpenEUICC/app-deps/maven/Android.bp" \
    "$ROM_ROOT/packages/apps/OpenEUICC/app-deps/maven/Android.bp"

command -v curl >/dev/null || fail "se necesita curl para descargar las dependencias de OpenEUICC"
curl -fL --retry 3 -o "$ROM_ROOT/packages/apps/OpenEUICC/app-deps/maven/zxing-android-embedded-4.3.0.aar" \
    "https://repo.maven.apache.org/maven2/com/journeyapps/zxing-android-embedded/4.3.0/zxing-android-embedded-4.3.0.aar"
curl -fL --retry 3 -o "$ROM_ROOT/packages/apps/OpenEUICC/app-deps/maven/core-3.4.1.jar" \
    "https://repo.maven.apache.org/maven2/com/google/zxing/core/3.4.1/core-3.4.1.jar"

[[ "$(sha256sum "$ROM_ROOT/packages/apps/OpenEUICC/app-deps/maven/zxing-android-embedded-4.3.0.aar" | awk '{print $1}')" == "$ZXING_AAR_SHA256" ]] ||
    fail "zxing-android-embedded no conserva la huella oficial"
[[ "$(sha256sum "$ROM_ROOT/packages/apps/OpenEUICC/app-deps/maven/core-3.4.1.jar" | awk '{print $1}')" == "$ZXING_CORE_SHA256" ]] ||
    fail "ZXing Core no conserva la huella oficial"

echo "Compatibilidad completa de LineageOS 24.0 aplicada correctamente."
echo "Kernel, módulos, cámara y WFD ya venían preparados desde sus repositorios A17."
echo "Se aplicaron los ajustes de plataforma y OpenEUICC."
echo "No se modificó build/soong/ui/build/rbe.go."
