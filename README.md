# Bash SHELL L1-Validator 
Skrip ini digunakan untuk mengatur dan mengkonfigurasi node validator Titan. Dengan skrip ini, Anda dapat dengan mudah menginisialisasi node Titan, mengunduh dan mengonfigurasi semua file yang diperlukan, serta membuat validator baru.

Cara Penggunaan
Untuk mengunduh dan menginstal skrip secara otomatis, jalankan perintah berikut di mesin VM Anda:

```
sudo apt-get update && sudo apt-get install -y wget && wget https://raw.githubusercontent.com/RyzenXT-hub/L1-Validator/main/validator.sh && sudo chmod +x validator.sh && sudo ./validator.sh
```
Jika Gagal / Error Silahkan copy dan jalankan perintah berikut : 
```
systemctl stop titan.service || true
systemctl disable titan.service || true
rm -rf ~/.titan/ ~/titan/ /etc/systemd/system/titan.service ~/validator.sh /root/backups/ /root/go/ /usr/local/go/ go1.21.0.linux-amd64.tar.gz && rm -rf $HOME/.titan $HOME/titan /usr/local/bin/titand

```
Perintah ini akan:

Memperbarui daftar paket dan menginstal wget.
Mengunduh skrip setup_titan_validator.sh dari repositori ini.
Memberikan izin eksekusi pada skrip.
Menjalankan skrip untuk mengatur node validator Titan Anda.

Hal yang perlu di perhatikan saat selesai membuat L1 validator : 
- Simpan kode phrase yang dihasilkan pada saat penginstallan 
- import kode phrase yang di hasilkan tadi ke wallet Keplr 
- lalu kirimkan token TNT sejumlah yang anda input saat peng-installan
- tunggu setidaknya 1-2 jam untuk validator dapat muncul pada browser blockchain titan.

#What's New
- Interaktif dengan Pengguna : Sekarang pengguna diminta untuk memasukkan moniker (nama unik node) dan nama akun mereka saat menjalankan skrip.
- Animasi Loading            : Proses instalasi ditandai dengan animasi loading kuning dan hasil yang berhasil ditampilkan dalam warna biru muda.
- Backup Otomatis            : Skrip ini secara otomatis menciptakan file backup untuk akun yang Anda masukkan dan seed phrase yang dihasilkan dari Titan Daemon. File     backup ini dapat ditemukan di direktori /root/backups/ dengan nama yang Anda masukkan di saat instalasi.
