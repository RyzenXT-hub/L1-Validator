#!/bin/bash

# Fungsi untuk memeriksa kegagalan
check_failure() {
  if [ $? -ne 0 ]; then
    echo -e "\e[41mKesalahan terjadi pada langkah sebelumnya, menghentikan skrip.\e[0m"
    exit 1
  fi
}

# Fungsi untuk menampilkan animasi loading
loading() {
  pid=$!
  while kill -0 $pid 2>/dev/null; do
    echo -ne "\e[33m[>    ]\e[0m\r"
    sleep 0.1
    echo -ne "\e[33m[>>   ]\e[0m\r"
    sleep 0.1
    echo -ne "\e[33m[>>>  ]\e[0m\r"
    sleep 0.1
    echo -ne "\e[33m[ >>> ]\e[0m\r"
    sleep 0.1
    echo -ne "\e[33m[  >>>]\e[0m\r"
    sleep 0.1
    echo -ne "\e[33m[   >>]\e[0m\r"
    sleep 0.1
    echo -ne "\e[33m[    >]\e[0m\r"
    sleep 0.1
  done
  echo -ne "\e[36m[✓]\e[0m\r"
  echo -ne "\n"
}

# Fungsi untuk menjalankan perintah dengan animasi loading
run_with_loading() {
  $1 &
  loading
  check_failure
}

# Meminta input dari pengguna
read -p "Masukkan moniker (nama unik untuk node Anda): " CUSTOM_MONIKER
read -p "Masukkan nama akun: " ACCOUNT_NAME
read -p "Masukkan alamat IP publik Anda yang statis: " IP_ADDRESS

# Konfigurasi node
CHAIN_ID="titan-test-1"
GAS_PRICE="0.0025uttnt"
SEED_NODE="bb075c8cc4b7032d506008b68d4192298a09aeea@47.76.107.159:26656"
ADDRBOOK_URL="https://raw.githubusercontent.com/nezha90/titan/main/addrbook/addrbook.json"
GENESIS_URL="https://raw.githubusercontent.com/nezha90/titan/main/genesis/genesis.json"
AMOUNT="10000" # Jumlah token TTNT yang ingin Anda delegasikan

# Instalasi Git dan Go
echo -e "\e[33mMemasang Git dan Go...\e[0m"
run_with_loading "apt-get update"
run_with_loading "apt-get install -y git vim"
run_with_loading "wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz"
run_with_loading "tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz"
export PATH=$PATH:/usr/local/go/bin
check_failure

# Clone dan bangun Titan CLI
echo -e "\e[33mMengkloning dan membangun Titan CLI...\e[0m"
run_with_loading "git clone https://github.com/nezha90/titan.git"
cd titan
run_with_loading "go build ./cmd/titand"
run_with_loading "cp titand /usr/local/bin"

# Inisialisasi node
echo -e "\e[33mMenginisialisasi node...\e[0m"
run_with_loading "titand init $CUSTOM_MONIKER --chain-id $CHAIN_ID"

# Konfigurasi node
echo -e "\e[33mMengonfigurasi node...\e[0m"
run_with_loading "sed -i \"s/^moniker *=.*/moniker = \\\"$CUSTOM_MONIKER\\\"/\" ~/.titan/config/config.toml"
run_with_loading "sed -i \"s/^seeds *=.*/seeds = \\\"$SEED_NODE\\\"/\" ~/.titan/config/config.toml"

# Unduh file genesis dan addrbook
echo -e "\e[33mMengunduh file genesis dan addrbook...\e[0m"
run_with_loading "wget -O ~/.titan/config/genesis.json $GENESIS_URL"
run_with_loading "wget -O ~/.titan/config/addrbook.json $ADDRBOOK_URL"

# Konfigurasi harga gas minimum
echo -e "\e[33mMengonfigurasi harga gas minimum...\e[0m"
run_with_loading "sed -i \"s/^minimum-gas-prices *=.*/minimum-gas-prices = \\\"$GAS_PRICE\\\"/\" ~/.titan/config/app.toml"

# Buat layanan systemd
echo -e "\e[33mMembuat layanan systemd...\e[0m"
cat <<EOT > /etc/systemd/system/titan.service
[Unit]
Description=Titan Daemon
After=network-online.target

[Service]
User=root
ExecStart=/usr/local/bin/titand start
Restart=always
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOT
check_failure

# Aktifkan dan mulai layanan
echo -e "\e[33mMengaktifkan dan memulai layanan...\e[0m"
run_with_loading "systemctl enable titan.service"
run_with_loading "systemctl start titan.service"

# Periksa status layanan
echo -e "\e[33mMemeriksa status layanan...\e[0m"
systemctl status titan.service

# Buat direktori backup jika belum ada
mkdir -p /root/backups/

# Buat akun baru dan backup seed phrase dengan nama yang dimasukkan pengguna
echo -e "\e[33mMembuat akun baru dan membackup seed phrase...\e[0m"
titand keys add $ACCOUNT_NAME > /root/backups/${CUSTOM_MONIKER}_wallet_backup.txt
check_failure
echo -e "\e[36mSeed phrase telah dibackup ke file /root/backups/${CUSTOM_MONIKER}_wallet_backup.txt\e[0m"

# Buat validator
echo -e "\e[33mMembuat validator...\e[0m"
run_with_loading "titand tx staking create-validator \
  --amount=${AMOUNT}uttnt \
  --pubkey=$(titand tendermint show-validator) \
  --chain-id=$CHAIN_ID \
  --moniker=$CUSTOM_MONIKER \
  --from=$ACCOUNT_NAME \
  --commission-max-change-rate=0.01 \
  --commission-max-rate=1.0 \
  --commission-rate=0.05 \
  --min-self-delegation=1 \
  --fees 500uttnt \
  --ip=$IP_ADDRESS"

echo -e "\e[36mSkrip selesai dijalankan. Node Titan Anda telah diatur dan berjalan.\e[0m"
