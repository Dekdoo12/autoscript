# Autoscript (Debian 12)

### INSTALL
```
apt update -y && apt install -y wget curl jq at screen unzip && wget -q https://raw.githubusercontent.com/Dekdoo12/autoscript/main/v5.sh && chmod +x v5.sh && screen -S install ./v5.sh
```

### UPDATE
```
wget -q https://raw.githubusercontent.com/Dekdoo12/autoscript/main/update.sh && chmod +x update.sh && ./update.sh
```

### Yang perlu Anda siapkan sendiri (tidak ada di repo)
- **Lisensi IP**: repo `kizaruvpn/izinsc` dengan file `ip` (format sama seperti sebelumnya).
- **Cloudflare (opsional)**: `/root/.cf.env` (chmod 600) berisi `CF_TOKEN=...` dan `CF_ZONE_DOMAIN=...` milik Anda.
- **Backup ke Google Drive (opsional)**: jalankan `rclone config`, buat remote bernama `dr`. Tanpa itu backup disimpan lokal di `/root/backups`.
- **Email backup (opsional)**: isi akun SMTP Anda di `/etc/msmtprc`.
- **Notifikasi Telegram saat install (opsional)**: `export KEY=<token> CHATID=<id>` sebelum menjalankan `v5.sh`.
- **SlowDNS**: siapkan record NS yang mengarah ke domain VPS.

### Port
TROJAN/VLESS/VMESS/SS WS+gRPC 443, VLESS/VMESS non-TLS 80, SSH 22/2222/2223, OpenVPN 1194 (tcp) & 2200 (udp).

### Xray OFF / gagal start
Jalankan `fixxray` (setelah update) atau:
```
wget -q -O fixxray https://raw.githubusercontent.com/Dekdoo12/autoscript/main/Fls/fixxray.sh && bash fixxray
```
