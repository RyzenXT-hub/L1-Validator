# L1-Validator
Skrip ini digunakan untuk mengatur dan mengkonfigurasi node validator Titan. Dengan skrip ini, Anda dapat dengan mudah menginisialisasi node Titan, mengunduh dan mengonfigurasi semua file yang diperlukan, serta membuat validator baru.

Cara Penggunaan
Untuk mengunduh dan menginstal skrip secara otomatis, jalankan perintah berikut di mesin VM Anda:

```
sudo apt-get update && sudo apt-get install -y wget && wget https://raw.githubusercontent.com/RyzenXT-hub/L1-Validator/main/setup_titan_validator.sh && chmod +x setup_titan_validator.sh && ./setup_titan_validator.sh
```
Jika Gagal / Error Silahkan gunakan perintah berikut : 
```
systemctl stop titan.service && systemctl disable titan.service && rm -rf ~/.titan/ ~/titan/ /etc/systemd/system/titan.service ~/setup_titan_validator.sh /root/backups/ /root/go/ /usr/local/go/ /root/titan/
 
```
Perintah ini akan:

Memperbarui daftar paket dan menginstal wget.
Mengunduh skrip setup_titan_validator.sh dari repositori ini.
Memberikan izin eksekusi pada skrip.
Menjalankan skrip untuk mengatur node validator Titan Anda.

#What's New
- Interaktif dengan Pengguna : Sekarang pengguna diminta untuk memasukkan moniker (nama unik node) dan nama akun mereka saat menjalankan skrip.
- Animasi Loading            : Proses instalasi ditandai dengan animasi loading kuning dan hasil yang berhasil ditampilkan dalam warna biru muda.
- Backup Otomatis            : Skrip ini secara otomatis menciptakan file backup untuk akun yang Anda masukkan dan seed phrase yang dihasilkan dari Titan Daemon. File     backup ini dapat ditemukan di direktori /root/backups/ dengan nama yang Anda masukkan di saat instalasi.
