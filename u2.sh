#!/bin/bash

# drosera_update.sh - Script untuk mengupdate node Drosera Network
# Berdasarkan: https://github.com/0xmoei/Drosera-Network/blob/main/update-old-nodes.md

# Kode warna untuk output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

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

# Check jika script dijalankan sebagai root
if [ "$EUID" -ne 0 ]; then
    print_error "Mohon jalankan script ini sebagai root (gunakan sudo)"
    exit 1
fi

# Langkah 1: Update Drosera CLI (Droseraup)
print_message "Mengupdate Drosera CLI..."
curl -L https://app.drosera.io/install | bash
source /root/.bashrc
droseraup
print_message "Drosera CLI telah diupdate"

# Langkah 2: Update Seed Node dalam drosera.toml
print_message "Memperbarui Seed Node di drosera.toml..."
cd ~/my-drosera-trap || {
    print_warning "Direktori my-drosera-trap tidak ditemukan di home. Masukkan path direktori trap Anda:"
    read -r TRAP_DIR
    cd "$TRAP_DIR" || {
        print_error "Direktori tidak valid. Keluar dari script."
        exit 1
    }
}

# Backup drosera.toml sebelum modifikasi
cp drosera.toml drosera.toml.backup

# Ganti seed node lama dengan yang baru
if grep -q "seed-node.testnet.drosera.io" drosera.toml; then
    sed -i 's|https://seed-node.testnet.drosera.io|https://relay.testnet.drosera.io|g' drosera.toml
    print_message "Seed Node telah diperbarui ke https://relay.testnet.drosera.io"
else
    print_warning "Seed Node lama tidak ditemukan di drosera.toml"
    print_warning "Mohon periksa dan perbarui secara manual seed node ke https://relay.testnet.drosera.io"
fi

# Langkah 3: Verifikasi alamat Trap
print_message "Memeriksa alamat Trap dalam drosera.toml..."
if grep -q "address = \"0x" drosera.toml; then
    print_message "Alamat Trap ditemukan dalam konfigurasi"
else
    print_warning "Alamat Trap tidak ditemukan dalam konfigurasi!"
    print_warning "Silakan kunjungi Dashboard di https://app.drosera.io/"
    print_warning "Tambahkan baris address = \"0x...\" di drosera.toml dengan alamat trap Anda"
    
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
print_message "Menerapkan kembali konfigurasi Drosera..."
read -p "Masukkan private key trap Anda: " private_key
if [[ -z "$private_key" ]]; then
    print_error "Private key tidak boleh kosong"
    exit 1
fi

DROSERA_PRIVATE_KEY=$private_key drosera apply
print_message "Konfigurasi diterapkan"

# Langkah 5: Membuka port UDP
print_message "Membuka port UDP yang diperlukan..."
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
print_message "Menjalankan kembali Node Operator..."

cd ~/Drosera-Network || {
    print_warning "Direktori Drosera-Network tidak ditemukan di home. Masukkan path direktori operator:"
    read -r OPERATOR_DIR
    cd "$OPERATOR_DIR" || {
        print_error "Direktori tidak valid. Keluar dari script."
        exit 1
    }
}

print_message "Menghentikan node..."
docker compose down -v

print_message "Memulai ulang node..."
docker compose up -d

print_message "Update selesai!"
print_message "Untuk melihat log node, jalankan: docker compose logs -f"
print_message "Catatan: Node mungkin menampilkan error pada awalnya, tunggu beberapa menit hingga log menjadi sehat."
print_message "Selamat! Operator Anda akan menghasilkan Green Blocks."
