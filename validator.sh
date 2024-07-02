#!/bin/bash

# Periksa apakah skrip dijalankan dengan hak akses root
if [ "$(id -u)" != "0" ]; then
    echo "Skrip ini memerlukan hak akses root."
    echo "Silakan coba jalankan ulang skrip dengan perintah 'sudo -i', lalu jalankan skrip ini kembali."
    exit 1
fi

# Periksa dan pasang Node.js dan npm
function install_nodejs_and_npm() {
    if command -v node > /dev/null 2>&1; then
        echo "Node.js sudah terpasang."
    else
        echo "Node.js belum terpasang, sedang memasang..."
        curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi

    if command -v npm > /dev/null 2>&1; then
        echo "npm sudah terpasang."
    else
        echo "npm belum terpasang, sedang memasang..."
        sudo apt-get install -y npm
    fi
}

# Periksa dan pasang PM2
function install_pm2() {
    if command -v pm2 > /dev/null 2>&1; then
        echo "PM2 sudah terpasang."
    else
        echo "PM2 belum terpasang, sedang memasang..."
        npm install pm2@latest -g
    fi
}

# Fungsi untuk mengecek dan mengatur alias
function check_and_set_alias() {
    local alias_name="art"
    local shell_rc="$HOME/.bashrc"

    # Gunakan .zshrc untuk pengguna Zsh
    if [ -n "$ZSH_VERSION" ]; then
        shell_rc="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        shell_rc="$HOME/.bashrc"
    fi

    # Periksa apakah alias sudah diatur
    if ! grep -q "$alias_name" "$shell_rc"; then
        echo "Mengatur alias '$alias_name' di $shell_rc"
        echo "alias $alias_name='bash $SCRIPT_PATH'" >> "$shell_rc"
        # Tambahkan pesan untuk mengaktifkan alias
        echo "Alias '$alias_name' sudah diatur. Jalankan 'source $shell_rc' untuk mengaktifkan alias, atau buka ulang terminal."
    else
        # Jika alias sudah diatur, berikan pesan informasi
        echo "Alias '$alias_name' sudah diatur di $shell_rc."
        echo "Jika alias tidak berfungsi, coba jalankan 'source $shell_rc' atau buka ulang terminal."
    fi
}

# Fungsi instalasi node
function install_node() {
    install_nodejs_and_npm
    install_pm2

    # Update dan instal paket-paket yang diperlukan
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y curl iptables build-essential git wget jq make gcc nano tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev lz4 snapd

    # Instal Go
    sudo rm -rf /usr/local/go
    curl -L https://go.dev/dl/go1.22.0.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
    echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile
    source $HOME/.bash_profile
    go version

    # Unduh semua file biner
    cd $HOME
    git clone https://github.com/nezha90/titan.git
    cd titan
    go build ./cmd/titand
    cp titand /usr/local/bin

    # Konfigurasi titand
    export MONIKER="My_Node"
    titand init $MONIKER --chain-id titan-test-1
    titand config node tcp://localhost:53457

    # Dapatkan file genesis dan addrbook awal
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
    sed -i -e 's/max_num_inbound_peers = 40/max_num_inbound_peers = 100/' -e 's/max_num_outbound_peers = 10/max_num_outbound_peers = 100/' $HOME/.titan/config/config.toml
    sed -i.bak -e "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"0.0025uttnt\"/;" ~/.titan/config/app.toml

    # Konfigurasi port
    node_address="tcp://localhost:53457"
    sed -i -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:53458\"%; s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:53457\"%; s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:53460\"%; s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:53456\"%; s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":53466\"%" $HOME/.titan/config/config.toml
    sed -i -e "s%^address = \"tcp://localhost:1317\"%address = \"tcp://0.0.0.0:53417\"%; s%^address = \":8080\"%address = \":53480\"%; s%^address = \"localhost:9090\"%address = \"0.0.0.0:53490\"%; s%^address = \"localhost:9091\"%address = \"0.0.0.0:53491\"%; s%:8545%:53445%; s%:8546%:53446%; s%:6065%:53465%" $HOME/.titan/config/app.toml
    echo "export TITAN_RPC_PORT=$node_address" >> $HOME/.bash_profile
    source $HOME/.bash_profile   

    pm2 start titand -- start && pm2 save && pm2 startup

    # Unduh snapshot
    titand tendermint unsafe-reset-all --home $HOME/.titan --keep-addr-book
    curl https://snapshots.dadunode.com/titan/titan_latest_tar.lz4 | lz4 -dc - | tar -xf - -C $HOME/.titan/data
    mv $HOME/.titan/priv_validator_state.json.backup $HOME/.titan/data/priv_validator_state.json

    # Gunakan PM2 untuk memulai proses node

    pm2 restart titand
    

    echo '====================== Instalasi selesai, silakan keluar dari skrip dan jalankan source $HOME/.bash_profile untuk memuat variabel lingkungan ==========================='
    
}

# Periksa status layanan titan
function check_service_status() {
    pm2 list
}

# Lihat log node titan
function view_logs() {
    pm2 logs titand
}

# Fungsi untuk menghapus node titan
function uninstall_node() {
    echo "Apakah Anda yakin ingin menghapus program node titan? Ini akan menghapus semua data terkait. [Y/N]"
    read -r -p "Konfirmasi: " response

    case "$response" in
        [yY][eE][sS]|[yY]) 
            echo "Memulai proses penghapusan node..."
            pm2 stop titand && pm2 delete titand
            rm -rf $HOME/.titand $HOME/titan $(which titand)
            echo "Program node titan berhasil dihapus."
            ;;
        *)
            echo "Operasi penghapusan dibatalkan."
            ;;
    esac
}

# Fungsi untuk menambahkan wallet baru
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
    read -p "Masukkan nama wallet Anda: " wallet_name
    read -p "Masukkan nama validator yang ingin Anda atur: " validator_name
    
titand tx staking create-validator \
--amount="1000000uttnt" \
--pubkey=$(titand tendermint show-validator) \
--moniker="$validator_name" \
--commission-max-change-rate=0.01 \
--commission-max-rate=1.0 \
--commission-rate=0.07 \
--min-self-delegation=1 \
--fees 500uttnt \
--from="$wallet_name" \
--chain-id=titan-test-1

}


# Fungsi untuk menyetorkan validator sendiri
function delegate_self_validator() {
read -p "Masukkan jumlah token yang ingin dititipkan: " math
read -p "Masukkan nama wallet: " wallet_name
titand tx staking delegate $(titand keys show $wallet_name --bech val -a)  ${math}art --from $wallet_name --fees 500uttnt

}

# Fungsi untuk mengekspor kunci privasi validator
function export_priv_validator_key() {
    echo "====================Silakan backup semua konten di bawah ini ke catatan atau spreadsheet Anda======================="
    cat ~/.titan/config/priv_validator_key.json
    
}


function update_script() {
    SCRIPT_URL="https://raw.githubusercontent.com/a3165458/titan/main/titan.sh"
    curl -o $SCRIPT_PATH $SCRIPT_URL
    chmod +x $SCRIPT_PATH
    echo "Skrip telah diperbarui. Keluar dari skrip ini, jalankan bash titan.sh untuk menjalankan skrip kembali."
}

# Menu utama
function main_menu() {
    while true; do
        clear
        echo "Skrip dan tutorial disusun oleh pengguna Twitter @y95277777, gratis dan open source. Jangan percaya pada yang memungut biaya."
        echo "============================Instalasi Node Titan============================"
        echo "Komunitas Node Telegram: https://t.me/niuwuriji"
        echo "Saluran Node Telegram: https://t.me/niuwuriji"
        echo "Komunitas Discord Node: https://discord.gg/GbMV5EcNWF"
        echo "Untuk keluar dari skrip, cukup tekan Ctrl+C di keyboard."
        echo "Pilih operasi yang ingin Anda lakukan:"
        echo "1. Instal node"
        echo "2. Buat wallet"
        echo "3. Impor wallet"
        echo "4. Periksa saldo wallet"
        echo "5. Periksa status sinkronisasi node"
        echo "6. Periksa status layanan saat ini"
        echo "7. Lihat log berjalan"
        echo "8. Hapus node"
        echo "9. Atur alias"
        echo "10. Buat validator"
        echo "11. Titipkan sendiri validator"
        echo "12. Ekspor kunci privasi validator"
        echo "13. Perbarui skrip ini"
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
