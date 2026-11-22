#!/bin/bash
# Perbaikan Xray untuk server yang SUDAH terpasang.
# Pakai:  bash xray-repair.sh                -> pertahankan config lama bila valid (akun aman)
#         bash xray-repair.sh --reset-config -> paksa pakai config baru (akun di config lama hilang, ada cadangan)
[ "$(id -u)" = 0 ] || { echo "Jalankan sebagai root"; exit 1; }
REPO="https://raw.githubusercontent.com/Dekdoo12/autoscript/main/"
RESET=0; [ "${1:-}" = "--reset-config" ] && RESET=1
ok(){ echo -e "\e[32m[OK]\e[0m $*"; }; er(){ echo -e "\e[31m[ERR]\e[0m $*"; }

# 1. binary Xray
if [ ! -x /usr/local/bin/xray ]; then
  for i in 1 2 3; do
    bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u www-data --version 1.8.24
    [ -x /usr/local/bin/xray ] && break; er "pasang Xray gagal ($i/3)"; sleep 3
  done
fi
[ -x /usr/local/bin/xray ] || { er "Binary Xray tidak terpasang. Periksa koneksi ke github.com"; exit 1; }
ok "binary: $(/usr/local/bin/xray version | head -n1)"

# 2. skrip prestart + unit service
cat >/usr/local/bin/xray-prestart <<'XRAYPRE'
#!/bin/bash
# Dijalankan sebagai root oleh systemd sebelum Xray start (ExecStartPre=+). Aman dijalankan manual.
CFG=/etc/xray/config.json
RUN=/run/xray/config.json
[ -f "$CFG" ] || { echo "xray-prestart: $CFG tidak ada" >&2; exit 1; }
# 1) log harus milik www-data (penyebab umum Xray gagal start: file log dibuat root)
install -d -o www-data -g www-data -m 755 /var/log/xray
touch /var/log/xray/access.log /var/log/xray/error.log
chown www-data:www-data /var/log/xray/access.log /var/log/xray/error.log
chmod 644 /var/log/xray/access.log /var/log/xray/error.log
# 2) config berisi UUID/password akun: tidak boleh dibaca user lain
chown root:www-data "$CFG"; chmod 640 "$CFG"
# 3) salinan runtime tanpa baris penanda akun (#vless, #& user exp, ### user exp ...)
install -d -o www-data -g www-data -m 750 /run/xray
sed -e 's/\r$//' -e '/^[[:space:]]*#/d' "$CFG" > "$RUN"
chown root:www-data "$RUN"; chmod 640 "$RUN"
XRAYPRE
chmod 755 /usr/local/bin/xray-prestart
rm -rf /etc/systemd/system/xray.service.d
cat >/etc/systemd/system/xray.service <<'XRAYUNIT'
[Unit]
Description=Xray Service
Documentation=https://github.com/XTLS/Xray-core
After=network.target nss-lookup.target

[Service]
User=www-data
Group=www-data
RuntimeDirectory=xray
RuntimeDirectoryMode=0750
NoNewPrivileges=true
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
ProtectSystem=full
ProtectHome=true
PrivateTmp=true
ExecStartPre=+/usr/local/bin/xray-prestart
ExecStartPre=/usr/local/bin/xray run -test -config /run/xray/config.json
ExecStart=/usr/local/bin/xray run -config /run/xray/config.json
Restart=on-failure
RestartSec=3
RestartPreventExitStatus=23
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
XRAYUNIT
systemctl daemon-reload
ok "service & prestart terpasang"

# 3. config
mkdir -p /etc/xray
check_cfg(){  # uji config dengan baris penanda akun (#...) dibuang
  local t r; t=$(mktemp); sed -e 's/\r$//' -e '/^[[:space:]]*#/d' "$1" > "$t"
  /usr/local/bin/xray run -test -config "$t" >/tmp/xray-test.log 2>&1; r=$?; rm -f "$t"; return $r; }
if [ $RESET = 0 ] && [ -s /etc/xray/config.json ] && check_cfg /etc/xray/config.json; then
  ok "config lama valid, akun dipertahankan"
else
  if [ -s /etc/xray/config.json ]; then
    B=/etc/xray/config.json.bak.$(date +%s); cp -a /etc/xray/config.json "$B"; er "config lama bermasalah/di-reset, cadangan: $B"
    [ -s /tmp/xray-test.log ] && sed 's/^/    /' /tmp/xray-test.log | head -n 8
  fi
  TPL="$(dirname "$(readlink -f "$0")")/../Cfg/config.json"
  if [ -s "$TPL" ]; then cp "$TPL" /etc/xray/config.json
  else wget -q -O /tmp/xray-cfg.new "${REPO}Cfg/config.json" && [ -s /tmp/xray-cfg.new ] && mv /tmp/xray-cfg.new /etc/xray/config.json \
       || { er "tidak bisa mengambil Cfg/config.json dari ${REPO}"; exit 1; }
  fi
  check_cfg /etc/xray/config.json || { er "config baru gagal uji:"; cat /tmp/xray-test.log; exit 1; }
  ok "config baru terpasang (akun harus dibuat ulang lewat menu)"
fi
rm -f /tmp/xray-test.log

# 4. jalankan
/usr/local/bin/xray-prestart
systemctl enable xray >/dev/null 2>&1
systemctl restart xray; sleep 2
if systemctl is-active --quiet xray; then
  ok "Xray AKTIF"; ss -ltn 2>/dev/null | grep -E '127\.0\.0\.1:1000[0-8]' | awk '{print "    listen " $4}'
else
  er "Xray belum aktif. 20 baris log terakhir:"; journalctl -u xray -n 20 --no-pager; exit 1
fi
