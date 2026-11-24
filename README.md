### INSTALL SCRIPT 
<pre><code>apt update -y && apt install -y wget curl jq at screen && wget -q https://raw.githubusercontent.com/Dekdoo12/autoscript/main/v5.sh && chmod +x v5.sh && screen -S install ./v5.sh
</code></pre>

### PERINTAH UPDATE 
<pre><code>wget -q https://raw.githubusercontent.com/Dekdoo12/autoscript/main/update.sh && chmod +x update.sh && ./update.sh</code></pre>

### FITUR TAMBAHAN
- Tambah Swap 1GiB
- Pemasangan yang dinamis
- Tuning profile pada server
- Xray Core (HTTPUpgrade & XHTTP aktif; akun WS otomatis ikut lewat /usr/local/bin/xray-sync)
- Penambahan fail2ban
- Auto block sebagian ads indo by default
- Auto clear log per 3 menit
- Auto deler expired
- User Details Akun

### PORT INFO
```
- TROJAN WS 443
- TROJAN GRPC 443
- TROJAN HTTPUPGRADE 443 / NONTLS 80 (path /hu-trojan)
- TROJAN XHTTP 443 (path /xh-trojan, alpn h2)
- SHADOWSOCKS WS 443
- SHADOWSOCKS GRPC 443
- VLESS WS 443
- VLESS GRPC 443
- VLESS NONTLS 80
- VLESS HTTPUPGRADE 443 (path /hu-vless)
- VLESS HTTPUPGRADE NONTLS 80 (path /hu-vless)
- VLESS XHTTP 443 (path /xh-vless, alpn h2)
- VMESS WS 443
- VMESS GRPC 443
- VMESS NONTLS 80
- VMESS HTTPUPGRADE 443 / NONTLS 80 (path /hu-vmess)
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
- HTTPUpgrade & XHTTP : pakai port 443/80 yang sama (XHTTP wajib alpn h2, tidak tersedia di port non-TLS)
- Always Use HTTPS : OFF
- UNDER ATTACK MODE : OFF
```
