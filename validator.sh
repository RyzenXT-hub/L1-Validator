#!/bin/bash

# Cek apakah script dijalankan sebagai root
if [ "$(id -u)" != "0" ]; then
    echo "Script ini harus dijalankan dengan hak akses root."
    echo "Silakan coba beralih ke pengguna root menggunakan perintah 'sudo -i' dan jalankan script ini lagi."
    exit 1
fi

# Fungsi untuk memeriksa dan menginstal Node.js dan npm
function install_nodejs_and_npm() {
    if command -v node > /dev/null 2>&1; then
        echo "Node.js sudah terinstal."
    else
        echo "Node.js belum terinstal, menginstal..."
        curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi

    if command -v npm > /dev/null 2>&1; then
        echo "npm sudah terinstal."
    else
        echo "npm belum terinstal, menginstal..."
        sudo apt-get install -y npm
    fi
}

# Fungsi untuk memeriksa dan menginstal PM2
function install_pm2() {
    if command -v pm2 > /dev/null 2>&1; then
        echo "PM2 sudah terinstal."
    else
        echo "PM2 belum terinstal, menginstal..."
        npm install pm2@latest -g
    fi
}

# Fungsi untuk mengatur alias secara otomatis
function check_and_set_alias() {
    local alias_name="art"
    local shell_rc="$HOME/.bashrc"

    # Untuk pengguna Zsh, gunakan .zshrc
    if [ -n "$ZSH_VERSION" ]; then
        shell_rc="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        shell_rc="$HOME/.bashrc"
    fi

    # Cek apakah alias sudah diatur
    if ! grep -q "$alias_name" "$shell_rc"; then
        echo "Mengatur alias '$alias_name' ke $shell_rc"
        echo "alias $alias_name='bash $SCRIPT_PATH'" >> "$shell_rc"
        # Tambahkan pengingat untuk mengaktifkan alias
        echo "Alias '$alias_name' sudah diatur. Silakan jalankan 'source $shell_rc' untuk mengaktifkan alias, atau buka terminal kembali."
    else
        # Jika alias sudah diatur, berikan pesan pengingat
        echo "Alias '$alias_name' sudah diatur di $shell_rc."
        echo "Jika alias tidak berfungsi, coba jalankan 'source $shell_rc' atau buka terminal kembali."
    fi
}

# Fungsi untuk menginstal node
function install_node() {
    install_nodejs_and_npm
    install_pm2

    # Update dan instal perangkat lunak yang diperlukan
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y curl iptables build-essential git wget jq make gcc nano tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev lz4 snapd

    # Instal Go
    sudo rm -rf /usr/local/go
    curl -L https://go.dev/dl/go1.22.0.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
    echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile
    source $HOME/.bash_profile
    go version

    # Instal semua file biner
    cd $HOME
    git clone https://github.com/nezha90/titan.git
    cd titan
    go build ./cmd/titand
    cp titand /usr/local/bin

    # Konfigurasi titand
    export MONIKER="Ryzen-Validator"
    titand init $MONIKER --chain-id titan-test-1
    titand config node tcp://localhost:53457

    # Dapatkan file genesis dan address book
    wget https://raw.githubusercontent.com/nezha90/titan/main/genesis/genesis.json
    mv genesis.json ~/.titan/config/genesis.json

    # Konfigurasi node
    SEEDS="bb075c8cc4b7032d506008b68d4192298a09aeea@47.76.107.159:26656"
    PEERS=""
    sed -i 's|^persistent_peers *=.*|persistent_peers = "'$PEERS'"|' $HOME/.titan/config/config.toml

    wget https://raw.githubusercontent.com/nezha90/titan/main/addrbook/addrbook.json
    mv addrbook.json ~/.titan/config/addrbook.json

    # Konfigurasi pruning
    sed -i -e "s/^pruning *=.*/pruning = \"custom\"/" $HOME/.titan/config/app.toml
    sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"100\"/" $HOME/.titan/config/app.toml
    sed -i -e "s/^pruning-keep-every *=.*/pruning-keep-every = \"0\"/" $HOME/.titan/config/app.toml
    sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"10\"/" $HOME/.titan/config/app.toml
    sed -i 's/max_num_inbound_peers = 40/max_num_inbound_peers = 100/' -e 's/max_num_outbound_peers = 10/max_num_outbound_peers = 100/' $HOME/.titan/config/config.toml
    sed -i.bak -e "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"0.0025uttnt\"/;" ~/.titan/config/app.toml

    # Konfigurasi port
    node_address="tcp://localhost:53457"
    sed -i -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:53458\"%; s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:53457\"%; s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:53460\"%; s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:53456\"%; s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":53466\"%" $HOME/.titan/config/config.toml
    sed -i -e "s%^address = \"tcp://localhost:1317\"%address = \"tcp://0.0.0.0:53417\"%; s%^address = \":8080\"%address = \":53480\"%; s%^address = \"localhost:9090\"%address = \"0.0.0.0:53490\"%; s%^address = \"localhost:9091\"%address = \"0.0.0.0:53491\"%; s%:8545%:53445%; s%:8546%:53446%; s%:6065%:53465%" $HOME/.titan/config/app.toml
    echo "export TITAN_RPC_PORT=$node_address" >> $HOME/.bash_profile
    source $HOME/.bash_profile   

    pm2 start titand -- start && pm2 save && pm2 startup

    # Unduh snapshot
    titand tendermint unsafe-reset-all --home $HOME/.artelad --keep-addr-book
    curl https://snapshots.dadunode.com/titan/titan_latest_tar.lz4 | lz4 -dc - | tar -xf - -C $HOME/.titan/data
    mv $HOME/.titan/priv_validator_state.json.backup $HOME/.titan/data/priv_validator_state.json

    # Gunakan PM2 untuk memulai proses node
    pm2 restart artelad
    
    echo '====================== Setelah instalasi selesai, keluar dari script dan jalankan source $HOME/.bash_profile untuk memuat variabel lingkungan ==========================='
}

# Cek status layanan titan
function check_service_status() {
    pm2 list
}

# Melihat log node titan
function view_logs() {
    pm2 logs titand
}

# Fungsi untuk menghapus node
function uninstall_node() {
    echo "Apakah Anda yakin ingin menghapus program node titan? Ini akan menghapus semua data terkait. [Y/N]"
    read -r -p "Silakan konfirmasi: " response

    case "$response" in
        [yY][eE][sS]|[yY]) 
            echo "Mulai menghapus program node..."
            pm2 stop titand && pm2 delete titand
            rm -rf $HOME/.titan $HOME/titan $(which titand)
            echo "Penghapusan program node selesai."
            ;;
        *)
            echo "Membatalkan operasi penghapusan."
            ;;
    esac
}

# Fungsi untuk membuat wallet
function add_wallet() {
    titand keys add wallet
}

# Fungsi untuk mengimpor wallet
function import_wallet() {
    titand keys add wallet --recover
}

# Fungsi untuk memeriksa saldo
function check_balances() {
    read -p "Masukkan alamat wallet: " wallet_address
    titand query bank balances "$wallet_address"
}

# Fungsi untuk melihat status sinkronisasi node
function check_sync_status() {
    titand status | jq .SyncInfo
}

# Fungsi untuk membuat validator
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

# Fungsi untuk melakukan delegasi ke validator sendiri
function delegate_self_validator() {
    read -p "Masukkan jumlah token yang di-stake: " math
    read -p "Masukkan nama wallet: " wallet_name
    titand tx staking delegate $(titand keys show $wallet_name --bech val -a) ${math}uttnt --from $wallet_name --fees 500uttnt
}

# Fungsi untuk mengekspor key validator
function export_priv_validator_key() {
    echo "====================Silakan backup semua isi berikut ini di notepad atau sheet excel Anda==========================================="
    cat ~/.titan/config/priv_validator_key.json
}

# Fungsi untuk memperbarui script
function update_script() {
    SCRIPT_URL="https://raw.githubusercontent.com/a3165458/titan/main/titan.sh"
    curl -o $SCRIPT_PATH $SCRIPT_URL
    chmod +x $SCRIPT_PATH
    echo "Script telah diperbarui. Silakan keluar dari script dan jalankan bash laodau.sh untuk menjalankan script lagi."
}

# Menu utama
function main_menu() {
    while true; do
        clear
        echo "============================Instalasi Node Titan===================================="
        echo "Untuk keluar dari script, tekan ctrl c pada keyboard"
        echo "Silakan pilih operasi yang ingin Anda jalankan:"
        echo "1. Instal node"
        echo "2. Buat wallet"
        echo "3. Impor wallet"
        echo "4. Cek saldo alamat wallet"
        echo "5. Cek status sinkronisasi node"
        echo "6. Cek status layanan saat ini"
        echo "7. Lihat log"
        echo "8. Hapus node"
        echo "9. Setel alias"  
        echo "10. Buat validator"  
        echo "11. Delegasi ke diri sendiri" 
        echo "12. Backup key private validator" 
        echo "13. Perbarui script ini" 
        read -p "Masukkan pilihan (1-13): " OPTION

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
            *) echo "Pilihan tidak valid." ;;
        esac
        echo "Tekan tombol apa saja untuk kembali ke menu utama..."
        read -n 1
    done
}

# Tampilkan menu utama
main_menu
