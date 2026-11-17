#!/bin/bash
export ARCH=arm64
export SUBARCH=arm64

OUT_ZIP_DIR="$HOME/android/Output"
mkdir -p "$OUT_ZIP_DIR"

ARGS="O=out ARCH=arm64 CC=clang CLANG_TRIPLE=aarch64-linux-gnu- CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-none-eabi- LD=ld.lld AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip LLVM_IAS=1"

make $ARGS rosemary_defconfig

make -j$(nproc) $ARGS \
  LOCALVERSION="" \
  KCFLAGS="-Wno-unused-command-line-argument -Wno-ignored-optimization-argument -Wno-default-const-init-var-unsafe -Wno-default-const-init-field-unsafe"

if [ -f "out/arch/arm64/boot/Image.gz-dtb" ] && [ -d "$HOME/android/AnyKernel3" ]; then
  rm -f "$HOME/android/AnyKernel3/Image"* "$HOME/android/AnyKernel3/dtbo.img"
  cp out/arch/arm64/boot/Image.gz-dtb "$HOME/android/AnyKernel3/"
  cd "$HOME/android/AnyKernel3"
  ZIP_NAME="Zenith-rosemary-$(date +%Y%m%d-%H%M).zip"
  zip -r9 "$OUT_ZIP_DIR/$ZIP_NAME" * -x .git README.md
  echo "==> Selesai! File zip tersimpan rapi di: $OUT_ZIP_DIR/$ZIP_NAME"
fi
