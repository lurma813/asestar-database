# ASESTAR Database

Server pusat untuk **memantau screentime siswa**: menerima data penggunaan aplikasi dari perangkat siswa, menyimpannya di MySQL, dan menyediakan **WebUI admin** untuk mengelola siswa, grup, jadwal upload, ekspor data, dan database.

Dirilis sebagai **program siap pakai** (Windows `.exe` dan Linux). Tidak perlu memasang Python atau library apa pun; cukup unduh, jalankan, dan buka browser.

> Repositori: <https://github.com/lurma813/asestar-database>

## Fitur

**Untuk perangkat siswa (API publik)**
- Login siswa dengan NISN + nama + ID perangkat
- Unggah data screentime berkelompok, idempoten (kirim ulang data yang sama tidak menggandakan baris)
- Sesi yang melewati tengah malam otomatis dipecah per hari
- Jadwal upload per perangkat (jendela waktu, masa tenggang, penyebaran waktu agar server tidak kebanjiran)
- Pembatasan laju per perangkat dan per IP

**Untuk admin (WebUI)**
- Dashboard ringkasan, kelola **Siswa** dan **Grup** (seleksi massal, urut NISN/nama, salin NISN/nama)
- **Import** siswa dari teks, CSV, atau JSON; **ekspor** siswa (JSON) dan screentime (CSV dengan rekap harian online/offline)
- **Retensi otomatis** (1 minggu / 1 bulan / 1 semester / 1 tahun) dengan opsi ekspor CSV sebelum data dihapus, plus hapus rentang, hapus semua, dan reset total (ada progres di UI)
- **DB Manager**: koneksi MySQL, buat/hapus database, lihat dan kosongkan tabel, optimasi, pratinjau isi tabel
- Akun "siswa" Admin permanen (NISN `0000000000`) untuk uji coba perangkat, dengan kontrol akses per endpoint
- Mode gelap/terang dan monitor server (CPU/RAM/disk)

**Keamanan dan ketahanan**
- Satu sesi admin aktif sekaligus (ada login paksa), logout otomatis saat server restart dan saat idle 5 menit
- Password admin di-hash **bcrypt**; password database di `setting.conf` dienkripsi
- Penguncian login admin setelah 5 kali gagal (5 menit)
- Saat database tidak terhubung, menu dan fitur yang membutuhkannya **dinonaktifkan dengan peringatan**, dan error ditampilkan ramah (tanpa traceback di console)

## Persyaratan

- Server **MySQL / MariaDB** yang bisa dihubungi dari komputer tempat program berjalan (boleh di mesin yang sama)
- Windows 10/11 64-bit **atau** Linux 64-bit (lihat catatan kompatibilitas di bawah)
- Browser modern untuk membuka WebUI

## Unduh

Ambil berkas terbaru di halaman **[Releases](https://github.com/lurma813/asestar-database/releases)**:

| Platform | Berkas |
|----------|--------|
| Windows | `asestar-database.exe` |
| Linux | `asestar-database` |

*(Nama berkas di atas contoh; sesuaikan dengan nama aset pada rilis.)*

## Menjalankan

### Windows

1. Simpan `asestar-database.exe` di folder sendiri (mis. `C:\ASESTAR\`).
2. Klik dua kali, atau jalankan dari Command Prompt:
   ```bat
   asestar-database.exe
   ```
3. Jika muncul peringatan **Windows Defender SmartScreen**, pilih *More info > Run anyway*. Program hasil PyInstaller yang belum bertanda tangan digital sering ditandai begitu; periksa checksum rilis bila ada.
4. Jika muncul dialog **Windows Firewall**, izinkan akses jaringan privat agar perangkat siswa bisa terhubung.

Jendela console harus **tetap terbuka**; menutupnya menghentikan server.

### Linux

```bash
chmod +x asestar-database
./asestar-database
```

Berkas dibangun untuk Linux 64-bit; agar bisa jalan, sistemmu harus memakai versi glibc yang sama atau lebih baru daripada mesin tempat berkas itu dibuat (distribusi yang lebih lama bisa gagal dengan error `GLIBC_x.xx not found`). Jika terjadi, buat issue dengan menyebut distribusi dan versinya.

### Buka WebUI

Setelah console menampilkan banner "Server berjalan", buka <http://localhost:1111/admin>.

Login dengan akun bawaan:

| Username | Password |
|----------|----------|
| `admin`  | `admin123` |

**Segera ganti password** di *Pengaturan > Akun Admin*. Perangkat lain di jaringan membuka `http://<IP-komputer-server>:1111/admin`.

Lupa password? Reset lewat command line (server tidak dijalankan):

```bash
asestar-database --reset-admin-password PasswordBaru123
```

## Menyiapkan database

Jika database belum ada, buka **DB Manager**, isi form *Koneksi Database* (host, port, user, password, nama database), lalu klik **Buat Database**. Tabel dibuat otomatis dan akun Admin permanen langsung tersedia. User MySQL yang dipakai harus berhak membuat database dan tabel.

Atau lewat command line (disimpan ke `setting.conf`, password terenkripsi):

```bash
asestar-database --db-host 192.168.1.20 --db-port 3306 --db-user app --db-password rahasia --db-name sekolah_auth
```

## Konfigurasi

### Argumen command line

| Argumen | Fungsi |
|---------|--------|
| `--host` | Alamat bind (default `0.0.0.0`) |
| `--port` | Port web (default `1111` atau env `PORT`) |
| `--debug` | Log verbose (akses log, traceback lengkap) |
| `--reset-admin-password PW` | Reset password admin lalu keluar |
| `--db-host` `--db-port` `--db-user` `--db-password` `--db-name` | Atur koneksi MySQL |

### Variabel lingkungan

| Variabel | Default | Keterangan |
|----------|---------|------------|
| `PORT` | `1111` | Port web |
| `DB_HOST` `DB_PORT` `DB_USER` `DB_PASSWORD` `DB_NAME` | `localhost` `3306` `root` (kosong) `sekolah_auth` | Nilai awal koneksi (dipakai saat `setting.conf` pertama kali dibuat) |
| `ADMIN_USERNAME` `ADMIN_PASSWORD` | `admin` `admin123` | Akun admin awal |
| `SECRET_KEY` | dibuat otomatis | Kunci tanda tangan sesi |
| `APP_NAME` `APP_LOGO` `APP_FAVICON` | `ASESTAR Database` `fa-solid fa-database` (kosong) | Branding; logo bisa URL gambar atau kelas Font Awesome |
| `IP_RATE_LIMIT` | `600/minute` | Batas per IP untuk endpoint siswa (naikkan bila satu sekolah memakai satu IP publik) |
| `TRUST_PROXY` | `0` | Set `1` hanya jika di belakang reverse proxy tepercaya |

Contoh: `set PORT=8080` (Windows) atau `PORT=8080 ./asestar-database` (Linux).

### Lokasi data

File konfigurasi **tidak** disimpan di folder program, melainkan di folder pengguna:

- Windows: `%APPDATA%\ASESTAR_DATABASE\`
- Linux: `~/.config/ASESTAR_DATABASE/`

Isinya: `setting.conf` (JSON), `session.key`, `secret.key` (kunci enkripsi password DB, **jangan hilang**), dan `error.log` (detail teknis error; lampirkan saat melapor bug). Untuk memindahkan server ke komputer lain, salin seluruh folder ini.

## Menjalankan otomatis

**Linux (systemd)** — buat `/etc/systemd/system/asestar.service`:

```ini
[Unit]
Description=ASESTAR Database
After=network.target mysql.service

[Service]
User=asestar
ExecStart=/opt/asestar/asestar-database
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

lalu `sudo systemctl enable --now asestar`. (Jalankan sebagai user biasa; folder config mengikuti home user tersebut.)

**Windows** — buat tugas di *Task Scheduler* dengan pemicu "At startup" yang menjalankan `asestar-database.exe`.

## WebUI

| Halaman | Alamat |
|---------|--------|
| Login / beranda | `/admin` |
| Dashboard | `/admin/dashboard` |
| Siswa | `/admin/siswa-ui` |
| Grup | `/admin/grup-ui` |
| Import | `/admin/import-ui` |
| Screentime | `/admin/screentime-ui` |
| Pengaturan | `/admin/pengaturan-ui` |
| DB Manager | `/admin/dbmanager-ui` |
| Tentang | `/admin/tentang-ui` |

## API perangkat siswa

Semua body JSON. Dibatasi 30 permintaan/menit per perangkat (header `X-Device-Id`) dan `IP_RATE_LIMIT` per IP.

```bash
# Login
curl -X POST http://localhost:1111/login -H "Content-Type: application/json" \
  -d '{"nama":"Siswa Uji","nisn":"9990000001","device_id":"dev-1","model":"Pixel"}'

# Unggah screentime (maks 500 item per permintaan)
curl -X POST http://localhost:1111/screentime -H "Content-Type: application/json" \
  -d '{"nama":"Siswa Uji","nisn":"9990000001","device_id":"dev-1","model":"Pixel",
       "data":[{"package":"com.contoh.app","app_name":"Contoh",
                "start":"2026-10-24 10:00:00","end":"2026-10-24 10:30:00","duration":1800}]}'

# Waktu upload terakhir
curl -X POST http://localhost:1111/screentime/last -H "Content-Type: application/json" \
  -d '{"nama":"Siswa Uji","nisn":"9990000001","device_id":"dev-1"}'

# Jadwal upload
curl "http://localhost:1111/schedule?nisn=9990000001&nama=Siswa%20Uji&device_id=dev-1&model=Pixel"
```

Format tanggal `YYYY-MM-DD HH:MM:SS`. NISN hanya huruf/angka, maksimal 10 karakter. Jika database mati, endpoint mengembalikan **HTTP 503** dengan `{"code": "db_unavailable", "detail": "..."}`.

## Pemecahan masalah

| Gejala | Penyebab / solusi |
|--------|-------------------|
| Menu Siswa/Screentime/dst. redup dan ada banner merah | Database tidak terhubung. Buka **DB Manager** untuk membuat atau menghubungkan database; fitur aktif otomatis saat pulih |
| Perangkat lain tidak bisa membuka WebUI | Izinkan port di firewall (Windows Firewall / `ufw allow 1111/tcp`) dan pakai IP komputer server, bukan `localhost` |
| Console hanya menampilkan "Terjadi kesalahan internal" | Detail ada di `error.log`; jalankan dengan `--debug` untuk melihat traceback |
| "Password DB tidak bisa didekripsi" | `secret.key` hilang atau berbeda. Masukkan ulang password di DB Manager |
| Login admin terkunci | Tunggu 5 menit atau restart server |
| Port sudah dipakai | Jalankan dengan `--port 8080` |
| Antivirus memblokir `.exe` | Wajar untuk program PyInstaller tanpa tanda tangan digital; tambahkan pengecualian atau periksa checksum rilis |

## Catatan keamanan

- Ganti password admin bawaan sebelum dipakai di jaringan sekolah.
- Cookie sesi tidak memakai flag `secure` (sesuai pemakaian HTTP di LAN). Pasang HTTPS lewat reverse proxy bila diekspos ke internet, lalu set `TRUST_PROXY=1`.
- Data berisi identitas siswa (NISN, nama): batasi akses jaringan dan jaga `setting.conf` serta `secret.key`.

## Melapor masalah

Buka [Issues](https://github.com/lurma813/asestar-database/issues) dan sertakan: versi (tertera di sidebar WebUI), sistem operasi, langkah yang dilakukan, dan isi `error.log` (hapus data sensitif terlebih dahulu).

## Lisensi

Belum ditentukan. Tentukan syarat penggunaan dan distribusi program ini (dan tambahkan berkas `LICENSE`) sebelum rilis dipublikasikan. Kode sumber tidak disertakan dalam repositori ini.
