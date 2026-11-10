#!/bin/bash
# Limit IP/kuota: semua file diambil dari repo sendiri (bukan repo pihak ketiga)
REPO="https://raw.githubusercontent.com/Dekdoo12/autoscript/main/"
mkdir -p /etc/xray
wget -q -O /usr/bin/limit-ip "${REPO}Fls/limit-ip"
sed -i 's/\r//' /usr/bin/limit-ip
chmod +x /usr/bin/limit-ip
for s in vmess vless trojan shadowsocks; do
  wget -q -O /etc/systemd/system/limit$s.service "${REPO}Fls/limit$s.service"
  wget -q -O /etc/xray/limit.$s "${REPO}Fls/$s"
  sed -i 's/\r//' /etc/xray/limit.$s
  chmod +x /etc/xray/limit.$s
done
systemctl daemon-reload
for s in vmess vless trojan shadowsocks; do
  systemctl enable --now limit$s
done
