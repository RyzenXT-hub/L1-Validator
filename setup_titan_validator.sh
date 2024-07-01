#!/bin/bash

# Cek izin root
if [ "$(id -u)" != "0" ]; then
    echo -e "\e[93mSkrip ini memerlukan hak akses root.\e[0m"
    echo -e "\e[93mSilakan jalankan skrip ini sebagai root dengan 'sudo -i' dan jalankan skrip lagi.\e[0m"
    exit 1
fi

# Fungsi untuk animasi loading
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
  echo -e "\e[93m$1\e[0m"
  $2
  loading
  echo -e "\e[96mProses berhasil.\e[0m"
}

# Instalasi Node.js dan npm jika belum terinstal
function install_nodejs_and_npm() {
    if command -v node > /dev/null 2>&1; then
        echo -e "\e[92mNode.js sudah terinstal.\e[0m"
    else
        echo -e "\e[93mNode.js belum terinstal, menginstal...\e[0m"
        curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi

    if command -v npm > /dev/null 2>&1; then
        echo -e "\e[92mnpm sudah terinstal.\e[0m"
    else
        echo -e "\e[93mnpm belum terinstal, menginstal...\e[0m"
        sudo apt-get install -y npm
    fi
}

# Instalasi PM2 jika belum terinstal
function install_pm2() {
    if command -v pm2 > /dev/null 2>&1; then
        echo -e "\e[92mPM2 sudah terinstal.\e[0m"
    else
        echo -e "\e[93mPM2 belum terinstal, menginstal...\e[0m"
        npm install pm2@latest -g
    fi
}

# Cek dan atur alias jika belum ada
function check_and_set_alias() {
    local alias_name="art"
    local shell_rc="$HOME/.bashrc"

    if [ -n "$ZSH_VERSION" ]; then
        shell_rc="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        shell_rc="$HOME/.bashrc"
    fi

    if ! grep -q "$alias_name" "$shell_rc"; then
        echo -e "\e[93mMengatur alias '$alias_name' di $shell_rc\e[0m"
        echo "alias $alias_name='bash $SCRIPT_PATH'" >> "$shell_rc"
        echo -e "\e[92mAlias '$alias_name' berhasil diatur. Jalankan 'source $shell_rc' untuk mengaktifkannya, atau buka ulang terminal.\e[0m"
    else
        echo -e "\e[92mAlias '$alias_name' sudah diatur di $shell_rc.\e[0m"
        echo -e "\e[92mJika alias tidak berfungsi, coba jalankan 'source $shell_rc' atau buka ulang terminal.\e[0m"
    fi
}

# Instalasi Node Titan
function install_node() {
    install_nodejs_and_npm
    install_pm2

    # Variabel konfigurasi
    export MONIKER="TitanNode1"

    # Update dan instalasi perangkat lunak yang diperlukan
    run_with_loading "Memperbarui dan menginstal perangkat lunak yang diperlukan..." "sudo apt update && sudo apt upgrade -y"
    run_with_loading "Menginstal paket pendukung..." "sudo apt install -y curl iptables build-essential git wget jq make gcc nano tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev lz4 snapd"

    # Instalasi Go
    run_with_loading "Mengunduh dan menginstal Go..." "sudo rm -rf /usr/local/go && curl -L https://go.dev/dl/go1.22.0.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local"
    echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile
    source $HOME/.bash_profile
    go version

    # Klona repositori Titan dan bangun Titan CLI
    cd $HOME
    run_with_loading "Mengkloning repositori Titan..." "git clone https://github.com/nezha90/titan.git"
    cd titan
    run_with_loading "Membangun Titan CLI..." "go build ./cmd/titand"
    run_with_loading "Menginstal Titan CLI ke /usr/local/bin..." "sudo cp titand /usr/local/bin"

    # Inisialisasi node Titan
    run_with_loading "Inisialisasi node Titan..." "titand init $MONIKER --chain-id titan-test-1"
    run_with_loading "Mengonfigurasi node Titan..." "titand config node tcp://localhost:53457"

    # Unduh file genesis dan addrbook
    run_with_loading "Mengunduh file genesis..." "wget https://raw.githubusercontent.com/nezha90/titan/main/genesis/genesis.json && mv genesis.json ~/.titan/config/genesis.json"

    # Konfigurasi node
    SEEDS="bb075c8cc4b7032d506008b68d4192298a09aeea@47.76.107.159:26656"
    sed -i 's|^persistent_peers *=.*|persistent_peers = "'$PEERS'"|' $HOME/.titan/config/config.toml
    run_with_loading "Mengunduh file addrbook..." "wget https://raw.githubusercontent.com/nezha90/titan/main/addrbook/addrbook.json && mv addrbook.json ~/.titan/config/addrbook.json"

    # Konfigurasi pruning
    sed -i -e "s/^pruning *=.*/pruning = \"custom\"/" $HOME/.titan/config/app.toml
    sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"100\"/" $HOME/.titan/config/app.toml
    sed -i -e "s/^pruning-keep-every *=.*/pruning-keep-every = \"0\"/" $HOME/.titan/config/app.toml
    sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"10\"/" $HOME/.titan/config/app.toml
    sed -i 's/max_num_inbound_peers = 40/max_num_inbound_peers = 100/' $HOME/.titan/config/config.toml
    sed -i 's/max_num_outbound_peers = 10/max_num_outbound_peers = 100/' $HOME/.titan/config/config.toml
    sed -i -e "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"0.0025uttnt\"/" $HOME/.titan/config/app.toml

    # Konfigurasi port
    node_address="tcp://localhost:53457"
    sed -i -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:53458\"%" \
           -e "s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:53457\"%" \
           -e "s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:53460\"%" \
           -e "s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:53456\"%" \
           -e "s%^laddr = \"tcp://0.0.0.0:26657\"%laddr = \"tcp://0.0.0.0:53457\"%" \
           -e "s%^p2p.laddr = \"tcp://0.0.0.0:26656\"%p2p.laddr = \"tcp://0.0.0.0:53456\"%" \
           -e "s%^p2p.laddr = \"tcp://0.0.0.0:26657\"%p2p.laddr = \"tcp://0.0.0.0:53457\"%" \
           -e "s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":53466\"%" \
           $HOME/.titan/config/config.toml
    sed -i -e "s%^address = \"tcp://localhost:1317\"%address = \"tcp://0.0.0.0:53417\"%" \
           -e "s%^address = \":8080\"%address = \":53480\"%" \
           -e "s%^address = \"localhost:9090\"%address = \"0.0.0.0:53490\"%" \
           -e "s%^address = \"localhost:9091\"%address = \"0.0.0.0:53491\"%" \
           -e "s%:8545%:53445%" \
           -e "s%:8546%:53446%" \
           -e "s%:6065%:53465%" \
           $HOME/.titan/config/app.toml
    echo "export TITAN_RPC_PORT=$node_address" >> $HOME/.bash_profile
    source $HOME/.bash_profile   

    # Start node menggunakan PM2
    pm2 start titand -- start && pm2 save && pm2 startup

    # Unduh snapshot
    run_with_loading "Mengunduh snapshot..." "titand tendermint unsafe-reset-all --home $HOME/.artelad --keep-addr-book && curl https://snapshots.dadunode.com/titan/titan_latest_tar.lz4 | lz4 -dc - | tar -xf - -C $HOME/.titan/data && mv $HOME/.titan/priv_validator_state.json.backup $HOME/.titan/data/priv_validator_state.json"

    # Restart node menggunakan PM2
    pm2 restart artelad

    echo -e "\e[92m====================== Setelah instalasi selesai, keluar dari skrip dan jalankan source $HOME/.bash_profile untuk memuat variabel lingkungan ==========================\e[0m"
}

# Fungsi untuk memeriksa status layanan Titan
function check_service_status() {
    pm2 list
}

# Fungsi untuk melihat log node Titan
function view_logs() {
    pm2 logs titand
}

# Fungsi untuk menghapus instalasi node Titan
function uninstall_node() {
    echo -e "\e[93mAnda yakin ingin menghapus program node titan? Ini akan menghapus semua data terkait.\e[0m [Y/N]"
    read -r -p "Silakan konfirmasi: " response

    case "$response" in
        [yY][eE][sS]|[yY]) 
            echo -e "\e[93mMulai menghapus program node...\e[0m"
            pm2 stop titand && pm2 delete titand
            rm -rf $HOME/.titand $HOME/titan $(which titand)
            echo -e "\e[92mPenghapusan program node selesai\e[0m"
            ;;
        *)
            echo -e "\e[92mBatalkan operasi penghapusan.\e[0m"
            ;;
    esac
}

# Fungsi untuk menambahkan wallet
function add_wallet() {
    titand keys add wallet
}

# Fungsi untuk mengimpor wallet
function import_wallet() {
    titand keys add wallet --recover
}

# Fungsi untuk memeriksa saldo wallet
function check_balances() {
    read -p "Masukkan alamat wallet: " wallet_address
    titand query bank balances "$wallet_address"
}

# Fungsi untuk memeriksa status sinkronisasi node
function check_sync_status() {
    titand status | jq .SyncInfo
}

# Fungsi untuk menambahkan validator
function add_validator() {
    read -p "Masukkan nama wallet: " wallet_name
    read -p "Masukkan nama validator: " validator_name
    
    titand tx staking create-validator \
    --amount="1000000uttnt" \
    --pubkey=$(titand tendermint show-validator) \
    --moniker="$validator_name" \
    --commission-max-change-rate=0.01 \
    --commission-max-rate=1.0 \
    --commission-rate=0.07 \
    --min-self-delegation=1 \
    --fees 500uttnt \
    --from="$wallet_name"
}

# Fungsi untuk menyetorkan ke validator sendiri
function delegate_self_validator() {
    read -p "Masukkan jumlah token yang dititipkan: " math
    read -p "Masukkan nama wallet: " wallet_name
    titand tx staking delegate $(titand keys show $wallet_name --bech val -a)  ${math}art --from $wallet_name --fees 500uttnt
}

# Fungsi untuk mengekspor kunci privasi validator
function export_priv_validator_key() {
    echo -e "\e[92m====================Silakan cadangkan semua konten berikut dalam notepad atau lembar Excel Anda===========================================\e[0m"
    cat ~/.titan/config/priv_validator_key.json
    
}

# Fungsi untuk memperbarui skrip ini
function update_script() {
    SCRIPT_URL="https://raw.githubusercontent.com/a3165458/titan/main/titan.sh"
    run_with_loading "Memperbarui skrip dari $SCRIPT_URL..." "curl -o $SCRIPT_PATH $SCRIPT_URL && chmod +x $SCRIPT_PATH"
    echo -e "\e[92mSkrip telah diperbarui. Silakan keluar dari skrip dan jalankan bash laodau.sh untuk menjalankan ulang skrip.\e[0m"
}

# Fungsi utama, menampilkan menu
function main_menu() {
    while true; do
        clear
        echo -e "\e[96m============================Instalasi Node Titan====================================\e[0m"
        echo -e "\e[93mUntuk keluar dari skrip, tekan ctrl c di keyboard\e[0m"
        echo -e "\e[93mSilakan pilih operasi yang ingin Anda jalankan:\e[0m"
        echo -e "\e[93m1. Instal node"
        echo -e "2. Buat wallet"
        echo -e "3. Impor wallet"
        echo -e "4. Periksa saldo wallet"
        echo -e "5. Periksa status sinkronisasi node"
        echo -e "6. Periksa status layanan saat ini"
        echo -e "7. Lihat log"
        echo -e "8. Hapus node"
        echo -e "9. Set alias"
        echo -e "10. Buat validator"
        echo -e "11. Setor ke validator sendiri"
        echo -e "12. Cadangkan kunci privat validator"
        echo -e "13. Perbarui skrip ini\e[0m"
        read -p "Silakan masukkan pilihan (1-13): " OPTION

        case $OPTION in
            1) install_node ;;
            2) add_wallet ;;
            3) import_wallet ;;
            4) check_balances ;;
            5) check_sync_status ;;
            6) check_service_status ;;
            7) view_logs ;;
            8) uninstall_node ;;
            9) check_and_set_alias ;;
            10) add_validator ;;
            11) delegate_self_validator ;;
            12) export_priv_validator_key ;;
            13) update_script ;;
            *) echo -e "\e[91mPilihan tidak valid.\e[0m" ;;
        esac
        echo -e "\e[93mTekan tombol apa saja untuk kembali ke menu utama...\e[0m"
        read -n 1
    done
}

# Menampilkan menu utama
main_menu
