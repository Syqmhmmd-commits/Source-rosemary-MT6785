#!/bin/bash
export ARCH=arm64
export SUBARCH=arm64

OUT_ZIP_DIR="$HOME/android/Output"
mkdir -p "$OUT_ZIP_DIR"

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "=================================================="
echo "==> Memulai build di branch: $CURRENT_BRANCH"
echo "=================================================="

# Setup Compiler
ARGS="O=out ARCH=arm64 CC=clang CLANG_TRIPLE=aarch64-linux-gnu- CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-none-eabi- LD=ld.lld AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip LLVM_IAS=1"

# Pilih Defconfig berdasarkan branch
if [ "$CURRENT_BRANCH" == "zenith-ksu" ]; then
    DEFCONFIG="rosemary_defconfig" # Pastikan di file ini udah ada CONFIG_KSU=y
else
    DEFCONFIG="rosemary_defconfig"
fi

# 1. Load Defconfig
make $ARGS $DEFCONFIG

# 2. Hapus Image lama (PENANGKAL ZOMBIE BUILD)
rm -f out/arch/arm64/boot/Image.gz-dtb
rm -f out/arch/arm64/boot/Image

# 3. Compile Kernel
echo "==> Sedang meng-compile kernel..."
make -j$(nproc) $ARGS \
  KCFLAGS="-Wno-unused-command-line-argument -Wno-ignored-optimization-argument -Wno-default-const-init-var-unsafe -Wno-default-const-init-field-unsafe"

# 4. Cek apakah compile sukses
if [ $? -ne 0 ]; then
    echo ""
    echo "❌ ================================================== ❌"
    echo "❌ BUILD GAGAL! Ada error saat compile kernel.     ❌"
    echo "❌ Silakan cek pesan error warna merah di atas.    ❌"
    echo "❌ ================================================== ❌"
    exit 1
fi

# 5. Proses Zip (Hanya jalan kalau compile sukses)
if [ -f "out/arch/arm64/boot/Image.gz-dtb" ] && [ -d "$HOME/android/AnyKernel3" ]; then
  echo "==> Compile sukses! Menyiapkan file zip..."
  
  rm -f "$HOME/android/AnyKernel3/Image"* "$HOME/android/AnyKernel3/dtbo.img"
  cp out/arch/arm64/boot/Image.gz-dtb "$HOME/android/AnyKernel3/"
  
  cd "$HOME/android/AnyKernel3"
  ZIP_NAME="Zenith-rosemary-${CURRENT_BRANCH}-$(date +%Y%m%d-%H%M).zip"
  zip -r9 "$OUT_ZIP_DIR/$ZIP_NAME" * -x .git README.md
  
  echo "=================================================="
  echo "✅ Selesai! File zip tersimpan di:"
  echo "✅ $OUT_ZIP_DIR/$ZIP_NAME"
  echo "=================================================="
else
  echo "⚠️  Compile selesai, tapi Image.gz-dtb tidak ditemukan atau folder AnyKernel3 tidak ada."
fi
