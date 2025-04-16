#!/bin/bash

# Fungsi untuk menampilkan logo & informasi awal
print_welcome_message() {
    echo -e "\033[1;37m"
    echo " _  _ _   _ ____ ____ _    ____ _ ____ ___  ____ ____ ___ "
    echo "|\\ |  \\_/  |__| |__/ |    |__| | |__/ |  \\ |__/ |  | |__]"
    echo "| \\|   |   |  | |  \\ |    |  | | |  \\ |__/ |  \\ |__| |    "
    echo -e "\033[1;32m"
    echo "Nyari Airdrop Auto install Drosera CLI Node"
    echo -e "\033[1;33m"
    echo "Telegram: https://t.me/nyariairdrop"
    echo -e "\033[0m"
}

# Tampilkan pesan selamat datang
print_welcome_message

# === Cek System Requirements ===
CPU_CORES=$(nproc)
if [ "$CPU_CORES" -lt 2 ]; then
  echo "❌ CPU Cores kurang dari 2. Diperlukan minimal 2 cores!"
  exit 1
fi

RAM_TOTAL=$(free -m | awk '/^Mem:/{print $2}')
if [ "$RAM_TOTAL" -lt 3900 ]; then
  echo "❌ RAM kurang dari 4 GB. Diperlukan minimal 4 GB!"
  exit 1
fi

DISK_FREE=$(df -BG / | tail -1 | awk '{print $4}' | sed 's/G//')
if [ "$DISK_FREE" -lt 20 ]; then
  echo "❌ Disk space kurang dari 20 GB. Diperlukan minimal 20 GB!"
  exit 1
fi

echo "✅ Spesifikasi VPS aman. Lanjut instalasi..."

# Ambil IP VPS otomatis
VPS_IP=$(curl -s ifconfig.me)

# Minta input user
read -p "Masukkan Github Email: " GIT_EMAIL
read -p "Masukkan Github Username: " GIT_USERNAME
read -p "Masukkan EVM Private Key (0x...): " PRIVATE_KEY
read -p "Masukkan EVM Public Address (0x...): " PUBLIC_ADDRESS

# Update & install dependencies
sudo apt-get update && sudo apt-get upgrade -y
sudo apt install curl ufw iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev -y

# Install Docker
sudo apt-get update -y && sudo apt-get upgrade -y
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove $pkg; done
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg -y
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y && sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
sudo docker run hello-world

# Install Drosera CLI
curl -L https://app.drosera.io/install | bash
source ~/.bashrc
droseraup

# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc
foundryup

# Install Bun
curl -fsSL https://bun.sh/install | bash
source ~/.bashrc

# Create trap directory
mkdir -p ~/my-drosera-trap && cd ~/my-drosera-trap

# Set git config
git config --global user.email "$GIT_EMAIL"
git config --global user.name "$GIT_USERNAME"

# Initialize Trap project
forge init -t drosera-network/trap-foundry-template

# Install bun dependencies & build
bun install
forge build

# Deploy Trap
DROSERA_PRIVATE_KEY=$PRIVATE_KEY drosera apply
echo "✅ Trap deployed! Jangan lupa untuk melakukan Bloom Boost di dashboard: https://app.drosera.io/"

# Sekarang konfigurasi whitelist untuk operator
echo -e "\n\n# Whitelist configuration\nprivate_trap = true\nwhitelist = [\"$PUBLIC_ADDRESS\"]" >> drosera.toml
echo "✅ Whitelist operator ditambahkan ke drosera.toml"

# Apply konfigurasi whitelist
DROSERA_PRIVATE_KEY=$PRIVATE_KEY drosera apply
echo "✅ Konfigurasi whitelist diterapkan"

# Kembali ke home directory
cd ~

# Install Operator CLI
curl -LO https://github.com/drosera-network/releases/releases/download/v1.16.2/drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
tar -xvf drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
sudo cp drosera-operator /usr/bin

# Test Operator CLI
drosera-operator --version

# Register operator
echo "✅ Mendaftarkan operator..."
drosera-operator register --eth-rpc-url https://ethereum-holesky-rpc.publicnode.com --eth-private-key $PRIVATE_KEY

# Menjalankan dryrun untuk fetch blocks
cd ~/my-drosera-trap
drosera dryrun
cd ~

# Create systemd service
sudo tee /etc/systemd/system/drosera.service > /dev/null <<EOF
[Unit]
Description=Drosera node service
After=network-online.target

[Service]
User=$USER
Restart=always
RestartSec=15
LimitNOFILE=65535
ExecStart=$(which drosera-operator) node --db-file-path $HOME/.drosera.db --network-p2p-port 31313 --server-port 31314 \
  --eth-rpc-url https://ethereum-holesky-rpc.publicnode.com \
  --eth-backup-rpc-url https://1rpc.io/holesky \
  --drosera-address 0xea08f7d533C2b9A62F40D5326214f39a8E3A32F8 \
  --eth-private-key $PRIVATE_KEY \
  --listen-address 0.0.0.0 \
  --network-external-p2p-address $VPS_IP \
  --disable-dnr-confirmation true

[Install]
WantedBy=multi-user.target
EOF

# Buka firewall
sudo ufw allow ssh
sudo ufw allow 22
sudo ufw enable
sudo ufw allow 31313/tcp
sudo ufw allow 31314/tcp

# Jalankan service
sudo systemctl daemon-reload
sudo systemctl enable drosera
sudo systemctl start drosera

# Tampilkan status
sudo systemctl status drosera --no-pager

echo "=== Instalasi selesai! ==="
echo "💡 Untuk melihat log node, jalankan: journalctl -u drosera.service -f"
echo "🔗 Kunjungi dashboard dan lakukan opt-in di https://app.drosera.io/"
echo "💰 Jangan lupa lakukan Bloom Boost (deposit ETH) di dashboard agar trap berfungsi dengan baik"
