#!/bin/bash

# drosera_update.sh - Script untuk mengupdate node Drosera Network
# Berdasarkan: https://github.com/0xmoei/Drosera-Network/blob/main/update-old-nodes.md

# Kode warna untuk output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fungsi untuk menampilkan logo & informasi awal
print_welcome_message() {
    echo -e "\033[1;37m"
    echo " _  _ _   _ ____ ____ _    ____ _ ____ ___  ____ ____ ___ "
    echo "|\\ |  \\_/  |__| |__/ |    |__| | |__/ |  \\ |__/ |  | |__]"
    echo "| \\|   |   |  | |  \\ |    |  | | |  \\ |__/ |  \\ |__| |    "
    echo -e "\033[1;32m"
    echo "Nyari Airdrop Auto Update Drosera Network Node"
    echo -e "\033[1;33m"
    echo "Telegram: https://t.me/nyariairdrop"
    echo -e "\033[0m"
}

# Tampilkan pesan selamat datang
print_welcome_message

# Fungsi untuk menampilkan pesan berwarna
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "\n${BLUE}[LANGKAH]${NC} $1"
}

# Check jika script dijalankan sebagai root
if [ "$EUID" -ne 0 ]; then
    print_error "Mohon jalankan script ini sebagai root (gunakan sudo)"
    exit 1
fi

# Deteksi Private Key dan Alamat Public dari sistem yang sudah ada
EXISTING_PRIVATE_KEY=""
EXISTING_PUBLIC_ADDRESS=""

# Cek apakah service file berisi private key
if [ -f "/etc/systemd/system/drosera.service" ]; then
    EXISTING_PRIVATE_KEY=$(grep "eth-private-key" /etc/systemd/system/drosera.service | grep -oP '(?<=--eth-private-key )[^ ]+')
    print_message "Private key terdeteksi dari service file"
fi

# Mendeteksi direktori trap
TRAP_DIR=""
if [ -d "$HOME/my-drosera-trap" ]; then
    TRAP_DIR="$HOME/my-drosera-trap"
    print_message "Direktori trap terdeteksi di: $TRAP_DIR"
else
    # Coba cari direktori trap jika tidak di lokasi default
    POSSIBLE_TRAP_DIRS=$(find $HOME -name "drosera.toml" -type f 2>/dev/null | xargs dirname 2>/dev/null)
    if [ ! -z "$POSSIBLE_TRAP_DIRS" ]; then
        # Ambil direktori pertama yang ditemukan
        TRAP_DIR=$(echo "$POSSIBLE_TRAP_DIRS" | head -n 1)
        print_message "Direktori trap terdeteksi di lokasi alternatif: $TRAP_DIR"
    fi
fi

# Jika direktori trap tidak ditemukan, minta input dari user
if [ -z "$TRAP_DIR" ]; then
    print_warning "Direktori trap tidak terdeteksi otomatis."
    read -p "Masukkan path lengkap direktori trap Anda (berisi drosera.toml): " TRAP_DIR
    if [ ! -f "$TRAP_DIR/drosera.toml" ]; then
        print_error "File drosera.toml tidak ditemukan di $TRAP_DIR. Pastikan direktori yang benar."
        exit 1
    fi
fi

# Minta private key jika belum terdeteksi
if [ -z "$EXISTING_PRIVATE_KEY" ]; then
    read -p "Masukkan EVM Private Key (0x...): " EXISTING_PRIVATE_KEY
    if [[ ! "$EXISTING_PRIVATE_KEY" == 0x* ]]; then
        print_error "Format private key tidak valid. Harus dimulai dengan '0x'"
        exit 1
    fi
fi

# Langkah 1: Update Drosera CLI (Droseraup)
print_step "1. Mengupdate Drosera CLI"
curl -L https://app.drosera.io/install | bash
source /root/.bashrc
export PATH=$PATH:$HOME/.drosera/bin
droseraup
print_message "Drosera CLI telah diupdate"

# Langkah 2: Update Seed Node dalam drosera.toml
print_step "2. Memperbarui Seed Node di drosera.toml"
cd "$TRAP_DIR" || {
    print_error "Gagal mengakses direktori trap: $TRAP_DIR"
    exit 1
}

# Backup drosera.toml sebelum modifikasi
cp drosera.toml drosera.toml.backup
print_message "Backup drosera.toml dibuat di: $TRAP_DIR/drosera.toml.backup"

# Ganti seed node lama dengan yang baru
if grep -q "seed-node.testnet.drosera.io" drosera.toml; then
    sed -i 's|https://seed-node.testnet.drosera.io|https://relay.testnet.drosera.io|g' drosera.toml
    print_message "Seed Node telah diperbarui ke https://relay.testnet.drosera.io"
else
    if grep -q "drosera_rpc" drosera.toml; then
        # Coba perbaiki seed node lainnya jika ditemukan
        sed -i 's|drosera_rpc = ".*"|drosera_rpc = "https://relay.testnet.drosera.io"|g' drosera.toml
        print_message "Seed Node telah diperbarui ke https://relay.testnet.drosera.io"
    else
        print_warning "Field drosera_rpc tidak ditemukan di drosera.toml"
        print_warning "Menambahkan konfigurasi seed node baru..."
        echo 'drosera_rpc = "https://relay.testnet.drosera.io"' >> drosera.toml
    fi
fi

# Langkah 3: Verifikasi alamat Trap
print_step "3. Memeriksa alamat Trap dalam drosera.toml"
if grep -q "address = \"0x" drosera.toml; then
    TRAP_ADDRESS=$(grep "address = \"0x" drosera.toml | grep -oP '(?<=address = ")[^"]+')
    print_message "Alamat Trap ditemukan: $TRAP_ADDRESS"
else
    print_warning "Alamat Trap tidak ditemukan dalam konfigurasi!"
    print_warning "Silakan kunjungi Dashboard di https://app.drosera.io/"
    print_warning "Tambahkan alamat trap Anda di drosera.toml"
    
    read -p "Apakah Anda ingin menambahkan alamat trap sekarang? (y/n): " add_address
    if [[ $add_address == "y" || $add_address == "Y" ]]; then
        read -p "Masukkan alamat trap Anda (format 0x...): " trap_address
        if [[ $trap_address == 0x* ]]; then
            echo "address = \"$trap_address\"" >> drosera.toml
            print_message "Alamat trap ditambahkan ke drosera.toml"
        else
            print_error "Format alamat tidak valid. Harus dimulai dengan '0x'"
        fi
    fi
fi

# Langkah 4: Menerapkan kembali konfigurasi Drosera
print_step "4. Menerapkan kembali konfigurasi Drosera"
print_message "Menjalankan: DROSERA_PRIVATE_KEY=$EXISTING_PRIVATE_KEY drosera apply"
print_warning "Ketika diminta, ketik 'ofc' dan tekan Enter"

DROSERA_PRIVATE_KEY=$EXISTING_PRIVATE_KEY drosera apply
print_message "Konfigurasi diterapkan"

# Langkah 5: Membuka port UDP
print_step "5. Membuka port UDP yang diperlukan"
print_message "Jika tidak yakin jenis operator mana yang Anda gunakan, pilih opsi 3 untuk membuka semua port yang diperlukan"
echo "1) Operator pertama (port 31313/udp dan 31314/udp)"
echo "2) Operator kedua (port 31315/udp dan 31316/udp)"
echo "3) Buka semua port (untuk kedua jenis operator)"
read -p "Pilihan Anda (1/2/3): " operator_type

if [[ $operator_type == "1" ]]; then
    ufw allow 31313/udp
    ufw allow 31314/udp
    print_message "Port 31313/udp dan 31314/udp telah dibuka"
elif [[ $operator_type == "2" ]]; then
    ufw allow 31315/udp
    ufw allow 31316/udp
    print_message "Port 31315/udp dan 31316/udp telah dibuka"
elif [[ $operator_type == "3" ]]; then
    ufw allow 31313/udp
    ufw allow 31314/udp
    ufw allow 31315/udp
    ufw allow 31316/udp
    print_message "Semua port operator telah dibuka (31313-31316/udp)"
else
    print_warning "Pilihan tidak valid. Membuka semua port untuk keamanan..."
    ufw allow 31313/udp
    ufw allow 31314/udp
    ufw allow 31315/udp
    ufw allow 31316/udp
    print_message "Semua port operator telah dibuka (31313-31316/udp)"
fi

# Langkah 6: Menjalankan kembali Node Operator
print_step "6. Memulai ulang Node Operator"

# Deteksi apakah menggunakan Docker Compose atau systemd
if [ -d "$HOME/Drosera-Network" ] && [ -f "$HOME/Drosera-Network/docker-compose.yml" ]; then
    print_message "Terdeteksi penggunaan Docker Compose"
    cd "$HOME/Drosera-Network"
    print_message "Menghentikan node..."
    docker compose down -v
    print_message "Memulai ulang node..."
    docker compose up -d
    print_message "Untuk melihat log node, jalankan: docker compose logs -f"
elif [ -f "/etc/systemd/system/drosera.service" ]; then
    print_message "Terdeteksi penggunaan systemd service"
    print_message "Memulai ulang drosera service..."
    systemctl daemon-reload
    systemctl restart drosera
    print_message "Untuk melihat log node, jalankan: journalctl -u drosera -f"
else
    print_warning "Tidak dapat mendeteksi metode yang digunakan untuk menjalankan node"
    print_warning "Silakan mulai ulang node Anda secara manual"
    
    echo "1) Restart dengan Docker Compose"
    echo "2) Restart dengan systemd service"
    read -p "Pilihan Anda (1/2): " restart_method
    
    if [[ $restart_method == "1" ]]; then
        read -p "Masukkan path direktori Docker Compose: " docker_dir
        cd "$docker_dir" || {
            print_error "Direktori tidak valid"
            exit 1
        }
        docker compose down -v
        docker compose up -d
    elif [[ $restart_method == "2" ]]; then
        systemctl daemon-reload
        systemctl restart drosera
    else
        print_error "Pilihan tidak valid"
    fi
fi

print_step "Status Node"
if [ -f "/etc/systemd/system/drosera.service" ]; then
    systemctl status drosera --no-pager
fi

print_message "Update selesai!"
print_message "Catatan: Node mungkin menampilkan error pada awalnya, tunggu beberapa menit hingga log menjadi sehat."
print_message "Selamat! Operator Anda akan menghasilkan Green Blocks."

print_step "Langkah-langkah berikutnya"
print_message "1. Verifikasi node Anda di dashboard: https://app.drosera.io/"
print_message "2. Pastikan node aktif dan menghasilkan Green Blocks"
print_message "3. Jika ada masalah, periksa log node"
