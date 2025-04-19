#!/bin/bash

# Warna untuk keterbacaan yang lebih baik
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # Tanpa Warna

echo -e "${GREEN}=== Script Pengaturan Node Drosera ===${NC}"
echo -e "${YELLOW}Script ini akan membantu Anda menyiapkan node Drosera sebagai layanan SystemD.${NC}"
echo

# Meminta Private Key
read -p "Masukkan private key Ethereum Anda (tanpa awalan 0x): " PV_KEY

# Memeriksa apakah private key telah dimasukkan
if [ -z "$PV_KEY" ]; then
    echo -e "${RED}Error: Private key tidak boleh kosong.${NC}"
    exit 1
fi

# Menambahkan awalan 0x jika belum ada
if [[ ! "$PV_KEY" == 0x* ]]; then
    PV_KEY="0x$PV_KEY"
    echo -e "${YELLOW}Menambahkan awalan 0x ke private key Anda.${NC}"
fi

# Mendeteksi IP VPS atau memungkinkan pengguna untuk menentukan
echo -e "\n${YELLOW}Mendeteksi alamat IP eksternal server Anda...${NC}"
DETECTED_IP=$(curl -s ifconfig.me)

echo -e "IP Terdeteksi: ${GREEN}$DETECTED_IP${NC}"
read -p "Gunakan IP ini? Atau masukkan IP yang berbeda (atau '0.0.0.0' untuk sistem lokal) [Tekan Enter untuk menggunakan IP terdeteksi]: " VPS_IP

# Jika tidak ada input, gunakan IP terdeteksi
if [ -z "$VPS_IP" ]; then
    VPS_IP=$DETECTED_IP
    echo -e "Menggunakan IP terdeteksi: ${GREEN}$VPS_IP${NC}"
fi

echo -e "\n${YELLOW}Membuat file layanan SystemD...${NC}"

# Membuat file layanan SystemD
sudo tee /etc/systemd/system/drosera.service > /dev/null <<EOF
[Unit]
Description=drosera node service
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
    --eth-private-key $PV_KEY \
    --listen-address 0.0.0.0 \
    --network-external-p2p-address $VPS_IP \
    --disable-dnr-confirmation true

[Install]
WantedBy=multi-user.target
EOF

echo -e "${GREEN}File layanan berhasil dibuat!${NC}"
echo -e "\n${YELLOW}Mengaktifkan dan memulai layanan Drosera...${NC}"

# Memuat ulang systemd dan mengaktifkan/memulai layanan
sudo systemctl daemon-reload
sudo systemctl enable drosera
sudo systemctl start drosera

echo -e "\n${GREEN}Layanan node Drosera telah dimulai!${NC}"
echo -e "${YELLOW}Berikut beberapa perintah yang berguna:${NC}"
echo -e "  ${GREEN}Cek log node:${NC} journalctl -u drosera.service -f"
echo -e "  ${GREEN}Hentikan node:${NC} sudo systemctl stop drosera"
echo -e "  ${GREEN}Mulai ulang node:${NC} sudo systemctl restart drosera"
echo
echo -e "${YELLOW}Catatan: Wajar jika Anda melihat pesan WARN seperti 'Failed to gossip message: InsufficientPeers'${NC}"
echo
echo -e "${GREEN}Jangan lupa untuk opt-in ke Trap di dashboard!${NC}"
echo -e "${YELLOW}Node Anda seharusnya mulai menghasilkan blok hijau di dashboard setelah semua dikonfigurasi.${NC}"
