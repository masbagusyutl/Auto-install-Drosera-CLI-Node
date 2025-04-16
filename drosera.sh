#!/bin/bash

# Periksa apakah ini adalah sesi setelah restart
if [ -f "$HOME/.drosera_restart_flag" ]; then
    echo -e "\033[1;32m====================================================\033[0m"
    echo -e "\033[1;32m       VPS berhasil di-restart secara otomatis      \033[0m" 
    echo -e "\033[1;32m    Melanjutkan instalasi Drosera Node dari awal    \033[0m"
    echo -e "\033[1;32m====================================================\033[0m"
    rm -f "$HOME/.drosera_restart_flag"
else
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

    # Simpan input ke file untuk digunakan setelah restart
    cat > "$HOME/.drosera_credentials" << EOL
    GIT_EMAIL="$GIT_EMAIL"
    GIT_USERNAME="$GIT_USERNAME"
    PRIVATE_KEY="$PRIVATE_KEY"
    PUBLIC_ADDRESS="$PUBLIC_ADDRESS"
    VPS_IP="$VPS_IP"
EOL
    chmod 600 "$HOME/.drosera_credentials"

    # Update & install dependencies
    echo "🔄 Update dan install dependencies..."
    sudo apt-get update && sudo apt-get upgrade -y
    sudo apt install curl ufw iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev -y

    # Install Docker
    echo "🔄 Menginstall Docker..."
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

    # Set auto-restart script
    cat > "$HOME/continue_drosera_install.sh" << 'EOL'
#!/bin/bash
source "$HOME/.drosera_credentials"
cd "$HOME"
touch "$HOME/.drosera_restart_flag"
bash "$HOME/d.sh"
EOL
    chmod +x "$HOME/continue_drosera_install.sh"

    # Configure auto-restart
    echo "🔄 Mengatur auto-restart VPS..."
    sudo tee /etc/systemd/system/drosera-continue.service > /dev/null << EOL
[Unit]
Description=Continue Drosera installation after reboot
After=network-online.target

[Service]
Type=simple
User=$USER
ExecStart=$HOME/continue_drosera_install.sh
Restart=no

[Install]
WantedBy=multi-user.target
EOL

    sudo systemctl daemon-reload
    sudo systemctl enable drosera-continue.service

    # Beri notifikasi tentang restart yang akan dilakukan
    echo -e "\n\n\033[1;33m⚠️ PERHATIAN: VPS AKAN DI-RESTART DALAM 10 DETIK! ⚠️\033[0m"
    echo -e "\033[1;36mProses instalasi Docker dan dependency lainnya memerlukan restart untuk mengaktifkan perubahan sistem.\033[0m"
    echo -e "\033[1;36mScript akan secara otomatis melanjutkan instalasi Drosera setelah restart.\033[0m"
    echo -e "\033[1;36mJika script tidak berjalan otomatis, Anda bisa menjalankan kembali: bash d.sh\033[0m"
    echo -e "\033[1;33mTunggu sekitar 2-3 menit setelah restart untuk masuk kembali ke VPS...\033[0m"
    echo -e "\n\033[1;31mProses restart dimulai dalam 10 detik...\033[0m"
    
    sleep 10
    sudo reboot
    exit 0
fi

# Load credentials setelah restart
if [ -f "$HOME/.drosera_credentials" ]; then
    source "$HOME/.drosera_credentials"
fi

# Disable auto-restart service after it's run once
sudo systemctl disable drosera-continue.service

# Install Drosera CLI dengan path yang benar
echo "🔄 Menginstall Drosera CLI..."
curl -L https://app.drosera.io/install | bash
source ~/.bashrc
export PATH=$PATH:$HOME/.drosera/bin
if ! command -v drosera &> /dev/null; then
    echo "⚠️ Drosera CLI tidak terdeteksi di PATH"
    if [ -f "$HOME/.drosera/bin/drosera" ]; then
        echo "✅ Ditemukan di $HOME/.drosera/bin/drosera, menambahkan ke PATH"
        export PATH=$PATH:$HOME/.drosera/bin
        echo 'export PATH=$PATH:$HOME/.drosera/bin' >> ~/.bashrc
    else
        echo "❌ Drosera CLI tidak ditemukan. Mencoba menginstal ulang..."
        curl -L https://app.drosera.io/install | bash
        source ~/.bashrc
        export PATH=$PATH:$HOME/.drosera/bin
    fi
fi
droseraup

# Verifikasi instalasi Drosera
if ! command -v drosera &> /dev/null; then
    echo "❌ Instalasi Drosera CLI gagal. Coba manual dengan:"
    echo "curl -L https://app.drosera.io/install | bash"
    echo "source ~/.bashrc"
    echo "export PATH=\$PATH:\$HOME/.drosera/bin"
    echo "droseraup"
    exit 1
fi

# Install Foundry
echo "🔄 Menginstall Foundry..."
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc
foundryup

# Install Bun
echo "🔄 Menginstall Bun..."
curl -fsSL https://bun.sh/install | bash
source ~/.bashrc
export PATH=$PATH:$HOME/.bun/bin
echo 'export PATH=$PATH:$HOME/.bun/bin' >> ~/.bashrc

# Create trap directory
echo "🔄 Membuat directory trap..."
mkdir -p ~/my-drosera-trap && cd ~/my-drosera-trap

# Set git config
git config --global user.email "$GIT_EMAIL"
git config --global user.name "$GIT_USERNAME"

# Initialize Trap project
echo "🔄 Menginisialisasi Trap project..."
forge init -t drosera-network/trap-foundry-template

# Install bun dependencies & build
echo "🔄 Menginstall dependencies dan build trap..."
$HOME/.bun/bin/bun install
forge build

# Verify drosera is available
echo "🔄 Verifikasi Drosera CLI..."
DROSERA_COMMAND=""
if command -v drosera &> /dev/null; then
    DROSERA_COMMAND="drosera"
elif [ -f "$HOME/.drosera/bin/drosera" ]; then
    DROSERA_COMMAND="$HOME/.drosera/bin/drosera"
else
    echo "❌ Drosera command tidak ditemukan. Coba install ulang."
    exit 1
fi

# Deploy Trap dengan interaksi manual
echo "🔄 Melakukan deploy Trap..."
echo "⚠️ PENTING: Ketika diminta, ketik 'ofc' dan tekan Enter"
echo "💡 Menjalankan: DROSERA_PRIVATE_KEY=$PRIVATE_KEY $DROSERA_COMMAND apply"
DROSERA_PRIVATE_KEY=$PRIVATE_KEY $DROSERA_COMMAND apply

# Verifikasi trap di dashboard
echo -e "\n\n🔄 Langkah 1: Verifikasi trap di dashboard"
echo "🔗 Kunjungi https://app.drosera.io/ dan hubungkan wallet Anda"
echo "📋 Cek trap Anda di 'Traps Owned' atau cari dengan alamat trap"
echo "⏳ Tekan ENTER setelah memverifikasi trap Anda muncul di dashboard..."
read -p "" verify_trap_deployed

# Run dryrun untuk fetch blocks
echo "🔄 Menjalankan dryrun untuk fetch blocks..."
$DROSERA_COMMAND dryrun

# Bloom Boost trap
echo -e "\n\n🔄 Langkah 2: Melakukan Bloom Boost pada trap"
echo "🔗 Kunjungi trap Anda di dashboard"
echo "💰 Klik pada 'Send Bloom Boost' dan deposit beberapa Holesky ETH"
echo "⏳ Tekan ENTER setelah melakukan Bloom Boost untuk melanjutkan..."
read -p "" verify_bloom_boost

# Konfigurasi whitelist untuk operator
echo -e "\n\n🔄 Langkah 3: Mengkonfigurasi whitelist operator..."
echo -e "\n\n# Whitelist configuration\nprivate_trap = true\nwhitelist = [\"$PUBLIC_ADDRESS\"]" >> drosera.toml
echo "✅ Whitelist operator ditambahkan ke drosera.toml"

# Apply konfigurasi whitelist
echo "🔄 Menerapkan konfigurasi whitelist..."
DROSERA_PRIVATE_KEY=$PRIVATE_KEY $DROSERA_COMMAND apply

# Sistem pengulangan untuk memastikan trap menjadi private
MAX_ATTEMPTS=3
attempts=0
trap_private=false

while [ $attempts -lt $MAX_ATTEMPTS ] && [ "$trap_private" = false ]; do
  ((attempts++))
  
  echo -e "\n\n🔄 Langkah 4: Memverifikasi status PRIVATE (Percobaan $attempts dari $MAX_ATTEMPTS)"
  echo "⏳ Menunggu konfigurasi privasi trap diterapkan..."
  echo "⚠️ PENTING: Silakan cek trap Anda di dashboard untuk memverifikasi statusnya"
  echo "🔗 Kunjungi https://app.drosera.io/"
  echo "📋 Trap Anda harus menunjukkan status 'PRIVATE'"
  
  read -p "Apakah trap Anda sudah berstatus PRIVATE? (y/n): " trap_status
  
  if [[ "$trap_status" == "y" || "$trap_status" == "Y" ]]; then
    trap_private=true
    echo "✅ Trap berhasil diatur menjadi PRIVATE!"
  else
    echo "❌ Trap belum berhasil diatur menjadi PRIVATE. Mencoba mengatur ulang..."
    echo "🔄 Memeriksa konfigurasi drosera.toml..."
    
    # Pastikan whitelist konfigurasi sudah benar
    if ! grep -q "private_trap = true" drosera.toml || ! grep -q "whitelist = \[\"$PUBLIC_ADDRESS\"\]" drosera.toml; then
      echo "🔄 Memperbaiki konfigurasi whitelist di drosera.toml..."
      # Hapus konfigurasi yang mungkin sudah ada tapi salah format
      sed -i '/private_trap/d' drosera.toml
      sed -i '/whitelist/d' drosera.toml
      # Tambahkan konfigurasi dengan format yang benar
      echo -e "\n# Whitelist configuration\nprivate_trap = true\nwhitelist = [\"$PUBLIC_ADDRESS\"]" >> drosera.toml
    fi
    
    echo "🔄 Mencoba menerapkan konfigurasi whitelist lagi..."
    DROSERA_PRIVATE_KEY=$PRIVATE_KEY $DROSERA_COMMAND apply
    
    echo "⏳ Tunggu sekitar 30 detik untuk memastikan transaksi dikonfirmasi..."
    sleep 30
  fi
done

if [ "$trap_private" = false ]; then
  echo "❌ Tidak berhasil mengatur trap menjadi PRIVATE setelah $MAX_ATTEMPTS kali percobaan."
  echo "⚠️ Anda dapat mencoba mengatur secara manual dengan langkah-langkah berikut:"
  echo "1. Edit file drosera.toml"
  echo "2. Pastikan ada baris 'private_trap = true'"
  echo "3. Pastikan ada baris 'whitelist = [\"$PUBLIC_ADDRESS\"]'"
  echo "4. Jalankan: DROSERA_PRIVATE_KEY=$PRIVATE_KEY $DROSERA_COMMAND apply"
  echo "5. Periksa dashboard untuk memverifikasi status"
  
  read -p "Apakah Anda ingin melanjutkan proses instalasi meskipun trap belum private? (y/n): " continue_anyway
  if [[ "$continue_anyway" != "y" && "$continue_anyway" != "Y" ]]; then
    echo "🛑 Instalasi dihentikan. Silakan coba lagi nanti."
    exit 1
  fi
  echo "⚠️ Melanjutkan instalasi meskipun trap belum private. Opt-in mungkin akan gagal."
else
  echo "🎉 Konfigurasi trap private berhasil! Melanjutkan proses instalasi..."
fi

# Kembali ke home directory
cd ~

# Install Operator CLI
echo -e "\n\n🔄 Langkah 5: Menginstall Operator CLI..."
curl -LO https://github.com/drosera-network/releases/releases/download/v1.16.2/drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
tar -xvf drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
sudo cp drosera-operator /usr/bin

# Test Operator CLI
echo "🔄 Testing Operator CLI..."
drosera-operator --version

# Register operator
echo -e "\n\n🔄 Langkah 6: Mendaftarkan operator..."
drosera-operator register --eth-rpc-url https://ethereum-holesky-rpc.publicnode.com --eth-private-key $PRIVATE_KEY

# Create systemd service
echo -e "\n\n🔄 Langkah 7: Membuat systemd service..."
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
echo -e "\n\n🔄 Langkah 8: Membuka port firewall..."
sudo ufw allow ssh
sudo ufw allow 22
sudo ufw enable
sudo ufw allow 31313/tcp
sudo ufw allow 31314/tcp

# Jalankan service
echo -e "\n\n🔄 Langkah 9: Menjalankan service drosera..."
sudo systemctl daemon-reload
sudo systemctl enable drosera
sudo systemctl start drosera

# Tampilkan status
echo "🔄 Status drosera service:"
sudo systemctl status drosera --no-pager

echo -e "\n\n🔄 Langkah 10: Opt-in Trap"
echo "🔗 Kunjungi dashboard Drosera: https://app.drosera.io/"
echo "📋 Buka trap Anda dan klik tombol 'Opt-in' untuk menghubungkan operator dengan Trap"
echo "⚠️ PENTING: Jika tombol 'Opt-in' tidak muncul atau proses gagal, pastikan:"
echo "  1. Trap sudah berstatus PRIVATE"
echo "  2. Alamat wallet Anda ($PUBLIC_ADDRESS) sudah benar di whitelist"
echo "  3. Transaksi whitelist sudah dikonfirmasi di blockchain"

echo -e "\n\n🔄 Langkah 11: Verifikasi Node Liveness"
echo "🔗 Di dashboard, trap Anda akan mulai menampilkan blok hijau jika semuanya berjalan dengan baik"
echo "📋 Ini menandakan node Anda aktif dan terhubung dengan benar"
echo "💡 Untuk melihat log node, jalankan: journalctl -u drosera.service -f"

# Membersihkan file kredensial setelah instalasi selesai
rm -f "$HOME/.drosera_credentials"
rm -f "$HOME/.drosera_restart_flag"
rm -f "$HOME/continue_drosera_install.sh"

echo -e "\n\n=== Instalasi selesai! ==="
echo "✅ Jika semua langkah telah dilakukan dengan benar, node Anda akan mulai berkontribusi ke jaringan Drosera"
echo "🎉 Terima kasih telah menggunakan script auto-install dari Nyari Airdrop!"
