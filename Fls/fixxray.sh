#!/bin/bash
# fixxray - diagnosa dan perbaiki Xray yang OFF / gagal start (Debian 12)
# Aman dijalankan berulang kali. Akun di config.json TIDAK dihapus kecuali Anda setuju (lihat langkah 7).

REPO="https://raw.githubusercontent.com/Dekdoo12/autoscript/main/"
XRAY_BIN="/usr/local/bin/xray"
CONF="/etc/xray/config.json"
XUSER="www-data"
GEO="/usr/local/share/xray"
LOGD="/var/log/xray"
XVER="1.8.24"

G='\e[32;1m'; R='\e[31;1m'; Y='\e[33;1m'; C='\e[36;1m'; N='\e[0m'
ok()   { echo -e "${G}[ OK ]${N} $*"; }
fix()  { echo -e "${Y}[FIX ]${N} $*"; }
bad()  { echo -e "${R}[ !! ]${N} $*"; }
step() { echo -e "\n${C}== $* ==${N}"; }

[ "$EUID" -eq 0 ] || { bad "Jalankan sebagai root"; exit 1; }
FAILED=0

# ---------------------------------------------------------------- 1
step "1. Status awal"
echo "Status service : $(systemctl is-active xray 2>/dev/null)"
echo "--- 15 baris log terakhir (journal) ---"
journalctl -u xray -n 15 --no-pager 2>/dev/null | tail -15
echo "--- RAM / swap ---"
free -m | awk 'NR==1||NR==2||NR==3'
if dmesg 2>/dev/null | grep -qi "out of memory"; then
  bad "Ada catatan OOM (RAM habis) di dmesg. VPS 1GB tanpa swap bisa mematikan Xray."
  dmesg 2>/dev/null | grep -i "out of memory" | tail -2
fi

# ---------------------------------------------------------------- 2
step "2. Paket pendukung"
for p in curl unzip; do
  command -v "$p" >/dev/null 2>&1 || { fix "memasang $p"; apt-get install -y "$p" >/dev/null 2>&1; }
done
ok "curl & unzip tersedia"
id "$XUSER" >/dev/null 2>&1 || { fix "user $XUSER tidak ada, membuat"; useradd -r -s /usr/sbin/nologin "$XUSER"; }
ok "user $XUSER ada"

# ---------------------------------------------------------------- 3
step "3. Binary Xray"
if [ ! -x "$XRAY_BIN" ] || ! "$XRAY_BIN" version >/dev/null 2>&1; then
  fix "binary Xray hilang/rusak, memasang ulang v$XVER"
  bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u "$XUSER" --version "$XVER"
  if [ ! -x "$XRAY_BIN" ] || ! "$XRAY_BIN" version >/dev/null 2>&1; then
    bad "Gagal memasang Xray (cek koneksi VPS ke github.com)"; FAILED=1
  fi
fi
[ -x "$XRAY_BIN" ] && ok "$("$XRAY_BIN" version 2>/dev/null | head -1)"

# ---------------------------------------------------------------- 4
step "4. File log & folder runtime"
mkdir -p "$LOGD" /run/xray
touch "$LOGD/access.log" "$LOGD/error.log"
chown -R "$XUSER:$XUSER" "$LOGD" /run/xray
chmod 755 "$LOGD" /run/xray
chmod 644 "$LOGD"/*.log
# /run hilang saat reboot -> buat otomatis
echo "d /run/xray 0755 $XUSER $XUSER -" > /etc/tmpfiles.d/xray.conf
ok "log milik $XUSER, /run/xray dibuat (permanen via tmpfiles.d)"

# ---------------------------------------------------------------- 5
step "5. Data geosite/geoip"
mkdir -p "$GEO"
dl() { # url file
  curl -fsSL --retry 3 --connect-timeout 15 -o "$2.tmp" "$1" \
    && [ "$(stat -c%s "$2.tmp" 2>/dev/null || echo 0)" -gt 100000 ] \
    && mv -f "$2.tmp" "$2" || { rm -f "$2.tmp"; return 1; }
}
geo_ok() { [ "$(stat -c%s "$GEO/$1" 2>/dev/null || echo 0)" -gt 100000 ]; }
if ! geo_ok geosite.dat; then
  fix "geosite.dat kosong/rusak, mengunduh ulang"
  dl "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat" "$GEO/geosite.dat" \
  || dl "https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat" "$GEO/geosite.dat" \
  || { bad "geosite.dat gagal diunduh"; FAILED=1; }
fi
if ! geo_ok geoip.dat; then
  fix "geoip.dat kosong/rusak, mengunduh ulang"
  dl "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat" "$GEO/geoip.dat" \
  || dl "https://github.com/v2fly/geoip/releases/latest/download/geoip.dat" "$GEO/geoip.dat" \
  || { bad "geoip.dat gagal diunduh"; FAILED=1; }
fi
chmod 644 "$GEO"/*.dat 2>/dev/null
geo_ok geosite.dat && geo_ok geoip.dat && ok "geosite.dat & geoip.dat valid"

# ---------------------------------------------------------------- 6
step "6. Service systemd"
rm -rf /etc/systemd/system/xray.service.d /etc/systemd/system/xray@.service.d
cat >/etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
Documentation=https://github.com
After=network.target nss-lookup.target
[Service]
User=$XUSER
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=$XRAY_BIN run -config $CONF
Restart=on-failure
RestartSec=3
RestartPreventExitStatus=23
LimitNOFILE=1000000
LimitNPROC=65535
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
ok "xray.service ditulis ulang (User=$XUSER)"

# ---------------------------------------------------------------- 7
step "7. Konfigurasi /etc/xray/config.json"
mkdir -p /etc/xray; chmod 755 /etc/xray
if [ ! -s "$CONF" ]; then
  fix "config.json hilang/kosong, mengunduh config bawaan"
  curl -fsSL -o "$CONF" "${REPO}Cfg/config.json" || { bad "gagal mengunduh config.json"; FAILED=1; }
fi
chmod 644 "$CONF" 2>/dev/null
if [ -x "$XRAY_BIN" ] && [ -s "$CONF" ]; then
  TEST=$(runuser -u "$XUSER" -- "$XRAY_BIN" run -test -config "$CONF" 2>&1); RC=$?
  if [ $RC -eq 0 ]; then
    ok "config.json valid (dites sebagai $XUSER)"
  else
    bad "config.json/izin bermasalah:"
    echo "$TEST" | tail -8
    cp -f "$CONF" "/root/xray-config.bak.$(date +%Y%m%d-%H%M%S)"
    if [ -t 0 ]; then
      echo -e "${Y}Reset config ke bawaan? Akun yang dibuat lewat menu akan hilang dari config${N}"
      echo "(backup tersimpan di /root/xray-config.bak.*; akun bisa dipulihkan lewat menu Backup/Restore)."
      read -rp "Reset config.json? [y/N]: " ans
      if [[ "$ans" =~ ^[Yy]$ ]]; then
        curl -fsSL -o "$CONF" "${REPO}Cfg/config.json" && chmod 644 "$CONF" && ok "config.json direset ke bawaan"
        TEST=$(runuser -u "$XUSER" -- "$XRAY_BIN" run -test -config "$CONF" 2>&1) || { bad "config bawaan juga gagal:"; echo "$TEST" | tail -5; FAILED=1; }
      else
        FAILED=1
      fi
    else
      FAILED=1
    fi
  fi
fi

# ---------------------------------------------------------------- 8
step "8. Bentrok port internal 10000-10008"
systemctl stop xray 2>/dev/null; sleep 1
CONFLICT=0
for p in $(seq 10000 10008); do
  L=$(ss -ltnpH "sport = :$p" 2>/dev/null)
  if [ -n "$L" ]; then
    bad "port $p dipakai: $(echo "$L" | grep -o 'users:.*' | head -1)"
    CONFLICT=1
  fi
done
[ $CONFLICT -eq 0 ] && ok "port 10000-10008 bebas"

# ---------------------------------------------------------------- 9
step "9. Menjalankan Xray"
systemctl reset-failed xray 2>/dev/null
systemctl enable xray >/dev/null 2>&1
systemctl restart xray
sleep 4
if systemctl is-active --quiet xray; then
  ok "XRAY AKTIF (running)"
  ss -ltnH "sport = :10001" 2>/dev/null | grep -q . && ok "Xray listen di 127.0.0.1:10001" || echo "catatan: port 10001 belum terlihat listen"
  systemctl restart nginx haproxy 2>/dev/null
  ok "nginx & haproxy direstart agar tersambung ulang ke Xray"
else
  bad "Xray masih belum aktif. Detail:"
  systemctl status xray --no-pager -l 2>/dev/null | head -12
  echo "--- journal ---"; journalctl -u xray -n 20 --no-pager 2>/dev/null | tail -20
  echo "--- error.log ---"; tail -10 "$LOGD/error.log" 2>/dev/null
  FAILED=1
fi

echo
if [ $FAILED -eq 0 ]; then
  echo -e "${G}Selesai: Xray sudah diperbaiki.${N}"
else
  echo -e "${R}Masih ada masalah. Kirim output di atas (terutama bagian [ !! ] dan journal) untuk dianalisis.${N}"
fi
exit $FAILED
