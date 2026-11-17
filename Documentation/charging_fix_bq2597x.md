================================================================================
CATATAN DEBUGGING & FIX PROBE DRIVER CHARGE PUMP (BQ2597X / SC8551)
Device   : Redmi Note 10S (rosemary) - MediaTek Helio G95
Kernel   : Linux 4.14 (S-vendor) | ROM: EvolutionX (S-vendor)
Compiler : Clang / LLVM Modern (Fedora)
Hasil    : Probe sukses, arus charging naik dari ratusan mA ke ~4758 mA
================================================================================

1. GEJALA AWAL
--------------
- Fast charging tidak berjalan; arus masuk tertahan di ratusan mA.
- Di dmesg muncul error:
  bq2597x_charger: probe of 7-0065 failed with error -615318528
  (Angka error berupa nilai besar acak/positif/negatif yang berubah-ubah
  setiap reboot, seperti -1688294400 atau 458058752).
- Tidak ada satupun log internal [bq2597x] yang tercetak sebelum probe gagal.

2. AKAR MASALAH (ROOT CAUSE)
----------------------------
- BUKAN masalah hardware ataupun partisi dtbo.img.
- Saat biner vmlinux diperiksa menggunakan llvm-objdump:
    llvm-objdump -d --start-address=0x$(nm out/vmlinux | grep " bq2597x_charger_probe$" | awk '{print $1}') out/vmlinux | head -n 20
  Seluruh isi fungsi bq2597x_charger_probe() ternyata dihapus oleh optimizer
  Clang/LLVM (-O2) dan disisakan hanya satu instruksi:
    ret
- Akibatnya, saat kernel memanggil drv->probe(client, id), fungsi langsung
  kembali (return) tanpa mengeksekusi baris apa pun dan mengembalikan sisa
  register argumen pertama (struct i2c_client *client), yaitu alamat pointer
  memori kernel yang teracak oleh KASLR.
- Clang modern melakukan Dead Code Elimination karena mendeteksi pola
  Undefined Behavior (UB) pada driver vendor kernel 4.14 lawas:
  a. Penggunaan tipe data `float` (static float sc8551_adc_lsb[]) dan header
     <asm/neon.h> di kernel space ARM64 (yang di-compile dengan flag
     -mgeneral-regs-only).
  b. Variabel lokal tidak diinisialisasi (`int ret;`) yang lolos kompilasi
     karena flag `-Wno-error=default-const-init-var-unsafe`, tetapi dianggap
     unreachable path oleh optimizer LLVM.
  c. Strict aliasing / type-punning pada `*(int *)match->data` serta tabel
     `of_device_id` non-const.
  d. Pengecekan properti DTBO `sc8551,ac-ovp-threshold` yang langsung
     menggagalkan probe jika properti tidak ditemukan di DTS/DTBO.

3. SOLUSI YANG DITERAPKAN
-------------------------
A. File: drivers/power/supply/ti/bq2597x_charger.c
   1) Menghapus `#include <asm/neon.h>` dan mengganti array `float` menjadi
      integer fixed-point (skala x10000) dengan `div_u64()`:
      - SC8551_IBUS_ADC_LSB  (1.5625)      -> 15625
      - SC8551_VBUS_ADC_LSB  (3.75)        -> 37500
      - SC8551_VAC_ADC_LSB   (5)           -> 50000
      - SC8551_VOUT_ADC_LSB  (1.25)        -> 12500
      - SC8551_VBAT_ADC_LSB  (1.25*1.0044) -> 12555
      - SC8551_IBAT_ADC_LSB  (3.125)       -> 31250
      - SC8551_TSBUS/TSBAT/TDIE (1.0)      -> 10000
   2) Menginisialisasi seluruh `int ret;` menjadi `int ret = 0;`.
   3) Mengubah `bq2597x_charger_match_table[]` menjadi `static const` dan
      mengamankan pembacaan `match->data`.
   4) Mengubah kegagalan baca `sc8551,ac-ovp-threshold` menjadi fallback ke
      nilai default `ti,bq2597x,ac-ovp-threshold` (tidak menggagalkan probe).
   5) Menambahkan atribut `__attribute__((optnone))` pada definisi fungsi
      `bq2597x_charger_probe()` agar Clang dilarang memangkas isi fungsi.

B. File: drivers/power/supply/ti/Makefile
   Menurunkan level optimasi dan mematikan strict-aliasing pada objek driver:
   CFLAGS_bq2597x_charger.o   := -O1 -fno-strict-aliasing -fno-delete-null-pointer-checks
   CFLAGS_pd_policy_manager.o := -O1 -fno-strict-aliasing -fno-delete-null-pointer-checks
   CFLAGS_cp_qc30.o           := -O1 -fno-strict-aliasing -fno-delete-null-pointer-checks

C. Packaging (AnyKernel3)
   - Karena source kernel dan ROM target sama-sama berbasis S-vendor, cukup
     memasukkan `Image.gz-dtb` saja ke dalam zip AnyKernel3 tanpa `dtbo.img`.

4. CHECKLIST PENCEGAHAN UNTUK BUILD KERNEL BERIKUTNYA
-----------------------------------------------------
[ ] Jika driver gagal probe dengan kode error angka acak (pointer KASLR),
    selalu cek hasil disassembly fungsi probe di `out/vmlinux` menggunakan
    `llvm-objdump -d`. Jika isinya cuma `ret`, berarti kena Dead Code
    Elimination dari Clang.
[ ] Hindari tipe data `float` / `double` dan `<asm/neon.h>` di driver kernel;
    selalu konversi ke integer fixed-point (`div_u64`).
[ ] Pasang `CFLAGS_<driver>.o := -O1 -fno-strict-aliasing` di Makefile atau
    `__attribute__((optnone))` pada fungsi probe driver vendor lawas.
[ ] Hapus `#define DEBUG` di baris atas driver setelah debugging selesai agar
    ring buffer `dmesg` tidak penuh oleh log interrupt saat charging.
================================================================================
