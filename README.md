# Progress Sepeda Hub — Flutter App

Rewrite total dari versi HTML/JS jadi app Flutter native. Sudah termasuk workflow
GitHub Actions supaya kamu bisa dapat file `.apk` **langsung dari HP, tanpa install
apapun** (tanpa Termux, tanpa Android Studio).

## Cara paling gampang dari HP: GitHub Actions

1. Buat akun GitHub kalau belum punya (gratis) — https://github.com/signup
2. Buat repository baru (kosong), misal namanya `progress-hub`.
3. Upload semua isi folder ini ke repo itu. Paling gampang lewat browser HP:
   - Buka repo → klik **Add file → Upload files**
   - Upload semua file & folder (termasuk folder `.github`, `lib`, `android`, `assets`)
   - Commit ke branch `main`
4. Buka tab **Actions** di repo kamu → workflow "Build APK" akan otomatis jalan
   (atau klik **Run workflow** kalau belum jalan sendiri).
5. Tunggu ~3-5 menit sampai selesai (centang hijau).
6. Klik run yang selesai → scroll ke bagian **Artifacts** → download `progress-hub-apk`.
7. Itu file zip berisi `app-release.apk` — extract, lalu install di HP Android kamu
   (mungkin perlu izinkan "install dari sumber tidak dikenal" di setting HP).

Repo di-set **private** juga tetap bisa pakai Actions gratis (2000 menit/bulan cukup
banget buat project ini).

## Kalau nanti punya akses laptop/PC

```bash
flutter pub get
flutter pub run flutter_launcher_icons
flutter build apk --release
```
File APK ada di `build/app/outputs/flutter-apk/app-release.apk`.

## Struktur project

- `lib/program.dart` — logika program latihan (target km per minggu, fase program)
- `lib/app_state.dart` — state + persistensi (SharedPreferences), streak, undo/redo
- `lib/screens/` — 3 tab: Hari Ini, Progress, Backup
- `lib/widgets/` — ring progress custom, kartu kaca (glass effect)
- `assets/icon.png` — sumber ikon app

## Catatan

- Data disimpan lokal di HP (SharedPreferences), sama seperti localStorage di versi web.
- Hardware acceleration diaktifkan eksplisit (`android:hardwareAccelerated="true"`)
  plus Impeller (renderer GPU baru Flutter) di `AndroidManifest.xml`.
- Ada toggle **Kualitas Grafis** di Pengaturan (ikon ⚙️ di pojok kanan atas):
  - **Hemat**: blur tipis, partikel sedikit — default, aman untuk GPU kelas
    Adreno 640 ke bawah (persis semangat komentar "eco mode" di kode HTML asli kamu).
  - **Penuh**: blur lebih dalam, glow ring & badge, partikel lebih banyak dan
    lebih halus — untuk GPU yang lebih kencang.
- Kalau mau ganti nama app/package id (`com.example.progress_hub`), edit
  `android/app/build.gradle` (applicationId) dan `android/app/src/main/AndroidManifest.xml` (label)
  sebelum build.
