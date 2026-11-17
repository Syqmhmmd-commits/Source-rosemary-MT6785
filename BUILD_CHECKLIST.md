# Checklist Pencegahan Build Kernel (Clang 17 / MT6785)

- [ ] Jika driver gagal probe dengan kode error angka acak (pointer KASLR), cek hasil disassembly fungsi probe di `out/vmlinux` menggunakan `llvm-objdump -d`. Jika isinya cuma `ret`, berarti kena Dead Code Elimination dari Clang.
- [ ] Hindari tipe data `float` / `double` dan `<asm/neon.h>` di driver kernel; selalu konversi ke integer fixed-point (`div_u64`).
- [ ] Pasang `CFLAGS_<driver>.o := -O1 -fno-strict-aliasing` di Makefile atau `__attribute__((optnone))` pada fungsi probe driver vendor lawas.
- [ ] Hapus `#define DEBUG` di baris atas driver setelah debugging selesai agar ring buffer `dmesg` tidak penuh oleh log interrupt saat charging.
