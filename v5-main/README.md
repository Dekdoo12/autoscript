### INSTALL SCRIPT 
<pre><code>apt update -y && apt install -y wget curl jq at screen && wget -q https://raw.githubusercontent.com/Dekdoo12/autoscript/main/v5.sh && chmod +x v5.sh && screen -S install ./v5.sh
</code></pre>

### PERINTAH UPDATE 
<pre><code>wget -q https://raw.githubusercontent.com/Dekdoo12/autoscript/main/update.sh && chmod +x update.sh && ./update.sh</code></pre>

### FITUR TAMBAHAN
- Tambah Swap 1GiB
- Pemasangan yang dinamis
- Tuning profile pada server
- Xray Core
- Penambahan fail2ban
- Auto block sebagian ads indo by default
- Auto clear log (access log tiap 1 menit, log lain tiap 10 menit)
- Auto deler expired
- User Details Akun

### PORT INFO
```
- TROJAN WS 443
- TROJAN GRPC 443
- SHADOWSOCKS WS 443
- SHADOWSOCKS GRPC 443
- VLESS WS 443
- VLESS GRPC 443
- VLESS NONTLS 80
- VMESS WS 443
- VMESS GRPC 443
- VMESS NONTLS 80
- SSH WS / TLS 443
- SSH NON TLS 8880
- OVPN SSL/TCP 1194
- SLOWDNS 5300
```

### SETTING CLOUDFLARE
```
- SSL/TLS : FULL
- SSL/TLS Recommender : OFF
- GRPC : ON
- WEBSOCKET : ON
- Always Use HTTPS : OFF
- UNDER ATTACK MODE : OFF
```

### KREDENSIAL (WAJIB DIBACA)
Repo ini **tidak lagi menyimpan token/password**. Buat file `/etc/kyt/secrets.conf` (chmod 600) di VPS **sebelum** menjalankan `v5.sh`
(contoh isi: `Cfg/secrets.conf.example`). Nilai yang kosong hanya menonaktifkan fitur terkait, installer tetap berjalan:
- `BOT_KEY`, `BOT_CHATID` : notifikasi instalasi / kuota habis / pointing domain
- `CF_KEY` : pembuatan subdomain otomatis (Random Domain). Tanpa ini installer beralih ke domain manual
- `BACKUP_BOT_TOKEN`, `BACKUP_CHAT_ID` : bot backup & restore (ditulis ke `/etc/bot/backupbot.conf`)
- `SMTP_USER`, `SMTP_PASS` : email (msmtp)
- `/etc/kyt/rclone.conf` : isi rclone.conf (Google Drive) untuk backup
Token lama yang pernah ada di repo harus dianggap bocor: **cabut/ganti** (BotFather, Cloudflare, Google, Gmail).

### CATATAN PERBAIKAN
- Aman: tanpa `eval` dari internet, kunci TLS 600 (tidak dicetak ke layar), OpenVPN CA/sertifikat dibuat unik per server
  (sertifikat bawaan lama sudah kedaluwarsa), unduhan konfigurasi tidak menimpa file lama bila gagal, sshd_config divalidasi (`sshd -t`).
- Bug: `/etc/bin` dibuat, cron `log_nginx`/`log_xray` (nama berisi titik diabaikan cron), `-y` di Ubuntu, `renew-nob`, `trojan-qouta`,
  cocok-IP lisensi persis (`grep -Fw`), `update.sh` mengembalikan menu lama bila gagal dan memakai `Cfg/m-noobz`.
- Opsional: `Fls/firewall-strict.sh` (default tolak, dry-run dulu).

### XRAY BARU (ringan & stabil)
- `Cfg/config.json` ditulis ulang: port, path, dan penanda akun (`#vless`, `#vmess`, ...) **sama persis** sehingga nginx/HAProxy dan semua menu tetap jalan.
  Dibersihkan dari blok `api`/`stats`/`policy` ganda, field tak valid, dan `freedom` memakai `UseIPv4` (mencegah lag karena IPv6 mati).
  Sniffing `routeOnly` (http/tls) mengaktifkan blokir BitTorrent yang di config lama tidak pernah aktif.
- `xray.service` baru: tiap start otomatis memperbaiki kepemilikan file log, mengunci izin config (640), membuang baris penanda akun ke salinan runtime
  `/run/xray/config.json` (Xray membaca JSON murni), lalu menguji config (`xray run -test`) sebelum jalan. Restart otomatis bila crash.
- Server yang sudah terpasang: `bash Fls/xray-repair.sh` (akun dipertahankan bila config valid) atau `--reset-config` (paksa config baru, cadangan disimpan).
- Diagnosa: `systemctl status xray -l`, `journalctl -u xray -n 40 --no-pager`.
