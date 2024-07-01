#!/bin/bash

# Check if script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "This script needs to be run with root user privileges."
    echo "Please try to switch to the root user using 'sudo -i' command and then run this script again."
    exit 1
fi

# Function to install Node.js and npm if not installed
function install_nodejs_and_npm() {
    if ! command -v node &> /dev/null; then
        echo "Node.js not installed. Installing..."
        curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
        sudo apt-get install -y nodejs
    else
        echo "Node.js already installed."
    fi

    if ! command -v npm &> /dev/null; then
        echo "npm not installed. Installing..."
        sudo apt-get install -y npm
    else
        echo "npm already installed."
    fi
}

# Function to install or update PM2 globally
function install_pm2() {
    if ! command -v pm2 &> /dev/null; then
        echo "PM2 not installed. Installing..."
        sudo npm install -g pm2@latest
    else
        echo "PM2 already installed."
    fi
}

# Function to set alias in shell configuration
function check_and_set_alias() {
    local alias_name="art"
    local shell_rc="$HOME/.bashrc"

    if [ -n "$ZSH_VERSION" ]; then
        shell_rc="$HOME/.zshrc"
    fi

    if ! grep -q "$alias_name" "$shell_rc"; then
        echo "Setting shortcut alias '$alias_name' in $shell_rc"
        echo "alias $alias_name='bash $SCRIPT_PATH'" >> "$shell_rc"
        echo "Please run 'source $shell_rc' to activate the shortcut, or reopen the terminal."
    else
        echo "Shortcut alias '$alias_name' already set in $shell_rc."
        echo "If the shortcut doesn't work, try running 'source $shell_rc' or reopen the terminal."
    fi
}

# Function to install Titan node and configure
function install_node() {
    install_nodejs_and_npm
    install_pm2

    # Update and install necessary packages
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y curl iptables build-essential git wget jq make gcc nano tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev lz4 snapd

    # Install Go
    sudo rm -rf /usr/local/go
    curl -L https://go.dev/dl/go1.22.0.linux-amd64.tar.gz | sudo tar -C /usr/local -xz
    echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile
    source $HOME/.bash_profile
    go version

    # Build and install Titan
    cd $HOME
    git clone https://github.com/nezha90/titan.git
    cd titan
    go build ./cmd/titand
    sudo cp titand /usr/local/bin

    # Configure Titan node
    export MONIKER="Ryzen-Node"
    titand init $MONIKER --chain-id titan-test-1
    titand config node tcp://localhost:53457

    # Download initial files and address book
    wget https://raw.githubusercontent.com/nezha90/titan/main/genesis/genesis.json -P ~/.titan/config/
    wget https://raw.githubusercontent.com/nezha90/titan/main/addrbook/addrbook.json -P ~/.titan/config/

    # Configure pruning and other settings
    sed -i -e "s/^pruning *=.*/pruning = \"custom\"/" $HOME/.titan/config/app.toml
    sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"100\"/" $HOME/.titan/config/app.toml
    sed -i -e "s/^pruning-keep-every *=.*/pruning-keep-every = \"0\"/" $HOME/.titan/config/app.toml
    sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"10\"/" $HOME/.titan/config/app.toml
    sed -i -e 's/max_num_inbound_peers = 40/max_num_inbound_peers = 100/' -e 's/max_num_outbound_peers = 10/max_num_outbound_peers = 100/' $HOME/.titan/config/config.toml
    sed -i.bak -e "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"0.0025uttnt\"/;" ~/.titan/config/app.toml

    # Configure ports
    node_address="tcp://localhost:53457"
    sed -i -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:53458\"%; s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:53457\"%; s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:53460\"%; s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:53456\"%; s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":53466\"%" $HOME/.titan/config/config.toml
    sed -i -e "s%^address = \"tcp://localhost:1317\"%address = \"tcp://0.0.0.0:53417\"%; s%^address = \":8080\"%address = \":53480\"%; s%^address = \"localhost:9090\"%address = \"0.0.0.0:53490\"%; s%^address = \"localhost:9091\"%address = \"0.0.0.0:53491\"%; s%:8545%:53445%; s%:8546%:53446%; s%:6065%:53465%" $HOME/.titan/config/app.toml
    echo "export TITAN_RPC_PORT=$node_address" >> $HOME/.bash_profile
    source $HOME/.bash_profile

    # Start Titan node with PM2
    pm2 start titand -- start && pm2 save && pm2 startup

    # Download snapshot
    titand tendermint unsafe-reset-all --home $HOME/.titan --keep-addr-book
    curl https://snapshots.dadunode.com/titan/titan_latest_tar.lz4 | lz4 -dc - | tar -xf - -C $HOME/.titan/data
    mv $HOME/.titan/priv_validator_state.json.backup $HOME/.titan/data/priv_validator_state.json

    # Restart Titan node
    pm2 restart titand

    echo '====================== After the installation is complete, please exit the script and execute source $HOME/.bash_profile to load the environment variables ==========================='
}

# Function to check Titan service status
function check_service_status() {
    pm2 list
}

# Function to view Titan node logs
function view_logs() {
    pm2 logs titand
}

# Function to uninstall Titan node
function uninstall_node() {
    echo "Are you sure you want to uninstall the Titan node program? This will delete all related data. [Y/N]"
    read -r -p "Please confirm: " response

    case "$response" in
        [yY][eE][sS]|[yY])
            echo "Start uninstalling the Titan node program..."
            pm2 stop titand && pm2 delete titand
            rm -rf $HOME/.titan $HOME/titan $(which titand)
            echo "Node program uninstallation completed"
            ;;
        *)
            echo "Cancel the uninstallation operation."
            ;;
    esac
}

# Function to add wallet
function add_wallet() {
    titand keys add wallet
}

# Function to import wallet
function import_wallet() {
    titand keys add wallet --recover
}

# Function to check wallet balance
function check_balances() {
    read -p "Please enter a wallet address: " wallet_address
    titand query bank balances "$wallet_address"
}

# Function to check node sync status
function check_sync_status() {
    titand status | jq .SyncInfo
}

# Function to create validator
function add_validator() {
    read -p "Please enter a wallet name: " wallet_name
    read -p "Please enter a validator name: " validator_name

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

# Function to delegate tokens to self as validator
function delegate_self_validator() {
    read -p "Please enter the amount of tokens to stake: " amount
    read -p "Please enter a wallet name: " wallet_name

    validator_address=$(titand keys show $wallet_name --bech val -a)
    titand tx staking delegate $validator_address ${amount}art --from $wallet_name --fees 500uttnt
}

# Function to export validator private key
function export_priv_validator_key() {
    echo "==================== Please back up all the following contents in your own notepad or excel sheet =========================="
    cat ~/.titan/config/priv_validator_key.json
}

# Function to update the script
function update_script() {
    SCRIPT_URL="https://raw.githubusercontent.com/a3165458/titan/main/titan.sh"
    curl -o $SCRIPT_PATH $SCRIPT_URL
    chmod +x $SCRIPT_PATH
    echo "The script has been updated. Please exit the script and execute bash $SCRIPT_PATH to rerun the script."
}

# Main menu function
function main_menu() {
    while true; do
        clear
        echo "============================ Titan Node Installation ===================================="
        echo "To exit the script, press Ctrl+C"
        echo "Please choose the operation you want to execute:"
        echo "1. Install node"
        echo "2. Create wallet"
        echo "3. Import wallet"
        echo "4. Check wallet address balance"
        echo "5. Check node sync status"
        echo "6. Check current service status"
        echo "7. View logs"
        echo "8. Uninstall node"
        echo "9. Set alias"
        echo "10. Create validator"
        echo "11. Delegate to self"
        echo "12. Backup validator private key"
        echo "13. Update this script"
        read -p "Please enter the option (1-13): " option

        case $option in
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
            *) echo "Invalid option." ;;
        esac

        echo "Press any key to return to the main menu..."
        read -n 1
    done
}

# Execute main menu
main_menu
