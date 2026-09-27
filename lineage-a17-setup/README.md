# Compatibilidad de LineageOS 24.0 para `eqe`

Este directorio conserva todo lo necesario para reproducir la primera
compilación completa de LineageOS 24.0 / Android 17 para el Motorola Edge 50 Pro
(`eqe`) a partir de las revisiones documentadas.

## Origen del respaldo

```text
lineage-a17-repro-20260925-final.tar.xz
SHA256: bcdaf88fd65be06bac724ef763f0928992a6f9b41a68196ef68c8617f903e266
```

Ese archivo comprimido permanece guardado por separado en la PC como respaldo
histórico. El repositorio contiene directamente su contenido extraído, con el
manifiesto actualizado para los repositorios A17. Las huellas vigentes de los
archivos integrados están registradas en su propio `SHA256SUMS`.

La preparación integrada incluye:

- manifiesto local con las revisiones exactas del dispositivo;
- una copia histórica de los parches usados para crear los repositorios A17;
- restauración de `libheif`;
- puente ABI de `SurfaceComposerClient` para el WFD de Android 16;
- parches históricos de la adaptación de WFD y cámara;
- descarga verificada de las dependencias QR de OpenEUICC.

Los binarios adaptados de cámara y WFD no están guardados en el kernel. Se
encuentran en sus repositorios Vendor A17 correspondientes. Las dependencias
Maven de OpenEUICC se descargan desde su origen oficial y se comprueba su
huella antes de utilizarlas.

El cambio de mensajes en `build/soong/ui/build/rbe.go` y los residuos de
compilación Awinic están excluidos porque no forman parte de la solución.

## Resultado comprobado

La compilación `userdebug` terminó correctamente y produjo:

```text
lineage-24.0-20260924-UNOFFICIAL-eqe.zip
Tamaño: 1716888712 bytes
SHA256: bf2ebe97443a06063c2f0bb01366ca94aa61d2e8afa07b0287ab456d14216195
```

`unzip -t` revisó el paquete completo y no encontró errores. Esto confirma la
compilación y la integridad del ZIP, pero no sustituye las pruebas de arranque y
hardware en el teléfono.

## Preparación de un servidor limpio

El servidor debe tener `repo`, `git-lfs`, `git` y `curl`. Mientras los
repositorios continúen privados, GitHub también debe estar autenticado para
poder descargarlos. El árbol de LineageOS se inicializa con soporte LFS:

```bash
mkdir -p /ruta/a/lineage-eqe-a17
cd /ruta/a/lineage-eqe-a17
repo init -u https://github.com/LineageOS/android.git -b lineage-24.0 --git-lfs
git lfs version
```

El Kernel A17 contiene este directorio dentro de
`lineage-a17-setup`. En un servidor nuevo se coloca primero el repositorio del
kernel en su ruta habitual, se instala el manifiesto y luego se sincroniza
LineageOS:

```bash
mkdir -p /ruta/a/lineage-eqe-a17/kernel/motorola
git clone --branch main \
  https://github.com/dvy-jp/android_kernel_motorola_sm7550_a17.git \
  /ruta/a/lineage-eqe-a17/kernel/motorola/sm7550

bash /ruta/a/lineage-eqe-a17/kernel/motorola/sm7550/lineage-a17-setup/preparar-manifiesto.sh \
  /ruta/a/lineage-eqe-a17
cd /ruta/a/lineage-eqe-a17
repo sync -c -j4
bash kernel/motorola/sm7550/lineage-a17-setup/aplicar-compatibilidad.sh "$PWD"
```

El último script ejecuta `git lfs pull`, comprueba la integridad de los tres
archivos grandes del Vendor Motorola y se detiene si falta alguno.

Los procedimientos verifican revisiones, estado limpio y huellas antes de
modificar archivos. No guardan credenciales ni crean commits. Si cambia alguna
base, se detienen para evitar aplicar una adaptación obsoleta.

El manifiesto descarga directamente el Kernel A17 y los módulos A17 marcados
como `a17-ready-v4`; ya no descarga las ramas A16 para parchearlas durante la
preparación.

## Repositorios privados

Las copias canónicas con historial también permanecen en:

- `dvy-jp/android_kernel_motorola_sm7550_a17`, rama `main`;
- `dvy-jp/android_kernel_motorola_sm7550-modules_a17`, rama `main`, commit
  `252f384314a467f70810a2aee2337ec27da55c1f`.

Los archivos cerrados permanecen en `proprietary_vendor_motorola_eqe_a17` y
`proprietary_vendor_qcom_wfd_a17`, que es donde corresponden por su función.
El Kernel A17 conserva solamente procedimientos, manifiesto y parches de texto.
