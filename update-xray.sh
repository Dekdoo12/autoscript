#!/bin/bash
# update-xray.sh - pasang / update Xray core pada VPS script v5.
#
# Pemakaian:
#   ./update-xray.sh                  update (atau pasang bila belum ada) ke 26.11.9
#   ./update-xray.sh 26.11.9          versi tertentu
#   ./update-xray.sh --rollback       kembali ke backup terakhir
#   ./update-xray.sh --install-only [versi]   hanya pasang binary + geodata (dipakai v5.sh)
#
# Alur: unduh -> verifikasi sha256 -> uji config dengan binary baru -> backup ->
# ganti binary -> restart -> cek kesehatan. Bila gagal, versi lama dipulihkan.
# Tidak menyentuh menu, /usr/local/sbin, atau data akun.

XRAY_VER_DEFAULT="26.11.9"
BIN="/usr/local/bin/xray"
CFG="/etc/xray/config.json"
ASSET="/usr/local/share/xray"
UNIT="/etc/systemd/system/xray.service"
BK_ROOT="/root/xray-backup"
WORK="/tmp/xray-upd"
LIMITS="limitvmess limitvless limittrojan limitshadowsocks"
API="127.0.0.1:10000"

R=$'\033[1;31m'; G=$'\033[1;32m'; Y=$'\033[1;33m'; N=$'\033[0m'
info() { echo "${Y}[*]${N} $*"; }
ok()   { echo "${G}[OK]${N} $*"; }
err()  { echo "${R}[X]${N} $*" >&2; }

MODE="update"; VER=""
for a in "$@"; do
    case "$a" in
        --rollback)     MODE="rollback" ;;
        --install-only) MODE="install-only" ;;
        *)              VER="$a" ;;
    esac
done

[ "$(id -u)" -eq 0 ] || { err "Jalankan sebagai root."; exit 1; }
for c in curl unzip sha256sum ss systemctl; do
    command -v "$c" >/dev/null 2>&1 || { err "Perintah '$c' tidak ditemukan (apt install -y curl unzip iproute2)."; exit 1; }
done

start_limits() { systemctl start $LIMITS >/dev/null 2>&1; }

restore_from() {
    local d="$1"
    [ -f "$d/xray.bin" ] && [ -f "$d/config.json" ] || { err "Backup tidak lengkap di $d"; return 1; }
    systemctl stop xray >/dev/null 2>&1
    install -m 755 -o root -g root "$d/xray.bin" "$BIN" || return 1
    cp -a "$d/config.json" "$CFG" || return 1
    systemctl restart xray
    sleep 3
    systemctl is-active --quiet xray
}

write_unit() {
cat > "$UNIT" <<'UNITEOF'
[Unit]
Description=Xray Service
Documentation=https://github.com
After=network.target nss-lookup.target
[Service]
User=www-data
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNOFILE=1000000
LimitNPROC=65535
[Install]
WantedBy=multi-user.target
UNITEOF
}

# ---------------- rollback manual ----------------
if [ "$MODE" = "rollback" ]; then
    LAST=$(ls -1dt "$BK_ROOT"/*/ 2>/dev/null | head -n1)
    [ -n "$LAST" ] || { err "Tidak ada backup di $BK_ROOT"; exit 1; }
    info "Rollback dari $LAST"
    systemctl stop $LIMITS >/dev/null 2>&1
    if restore_from "${LAST%/}"; then ok "Rollback selesai: $($BIN version | head -n1)"; start_limits; exit 0
    else err "Rollback gagal: journalctl -u xray -n 50"; start_limits; exit 1; fi
fi

VER="${VER:-$XRAY_VER_DEFAULT}"; VER="${VER#v}"
[[ "$VER" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { err "Format versi salah: $VER (contoh 26.11.9)"; exit 1; }

FRESH=0
[ -x "$BIN" ] || FRESH=1
if [ "$FRESH" = 1 ]; then
    info "Xray belum terpasang di $BIN, mode PASANG BARU."
else
    CUR=$($BIN version 2>/dev/null | head -n1)
    info "Terpasang : ${CUR:-tidak diketahui}"
fi
info "Target    : Xray $VER"
if [ "$FRESH" = 0 ] && [ "$MODE" = "update" ]; then
    case "$CUR" in *" $VER "*) ok "Sudah versi $VER, tidak ada yang perlu dilakukan."; exit 0;; esac
fi

# ---------------- 1. unduh + verifikasi ----------------
rm -rf "$WORK"; mkdir -p "$WORK/new" || exit 1
cd "$WORK" || exit 1
URL="https://github.com/XTLS/Xray-core/releases/download/v${VER}"
info "Mengunduh Xray-linux-64.zip ..."
curl -fL --retry 3 --connect-timeout 15 -o xray.zip "$URL/Xray-linux-64.zip" \
    || { err "Unduh zip gagal (versi ada? koneksi ke github.com?)."; exit 1; }
curl -fL --retry 3 --connect-timeout 15 -o xray.zip.dgst "$URL/Xray-linux-64.zip.dgst" \
    || { err "Unduh file checksum gagal."; exit 1; }
WANT=$(grep -i -m1 -E 'SHA2?-?256' xray.zip.dgst | awk '{print $NF}' | tr 'A-F' 'a-f')
GOT=$(sha256sum xray.zip | awk '{print $1}')
[[ "$WANT" =~ ^[0-9a-f]{64}$ ]] || { err "Tidak bisa membaca SHA256 dari file .dgst. Dibatalkan."; exit 1; }
[ "$WANT" = "$GOT" ] || { err "SHA256 tidak cocok! Dibatalkan."; err " seharusnya: $WANT"; err " didapat   : $GOT"; exit 1; }
ok "SHA256 cocok"
unzip -q -o xray.zip -d new || { err "Ekstrak zip gagal."; exit 1; }
[ -f new/xray ] || { err "Binary 'xray' tidak ada di zip."; exit 1; }
chmod +x new/xray
NEWV=$(new/xray version 2>/dev/null | head -n1)
case "$NEWV" in *" $VER "*) ok "Binary baru: $NEWV";; *) err "Versi binary tidak sesuai: $NEWV"; exit 1;; esac

# geodata: pakai yang ada; kalau belum ada, ambil dari zip rilis
install_assets() {
    mkdir -p "$ASSET"
    for f in geoip.dat geosite.dat; do
        [ -s "$ASSET/$f" ] || { [ -f "$WORK/new/$f" ] && install -m 644 "$WORK/new/$f" "$ASSET/$f" && info "geodata $f dipasang dari rilis"; }
    done
}

# ---------------- mode install-only (dipanggil v5.sh) ----------------
if [ "$MODE" = "install-only" ]; then
    install -m 755 -o root -g root "$WORK/new/xray" "$BIN" || { err "Gagal memasang binary."; exit 1; }
    install_assets
    ok "Binary terpasang: $($BIN version | head -n1)"
    rm -rf "$WORK"; exit 0
fi

# ---------------- 2. uji config dengan binary baru ----------------
[ -f "$CFG" ] || { err "$CFG tidak ada, tidak bisa dilanjutkan."; exit 1; }
install_assets
info "Menguji $CFG dengan binary baru ..."
XRAY_LOCATION_ASSET="$ASSET" new/xray run -test -config "$CFG" > "$WORK/test.log" 2>&1
if ! grep -qi "Configuration OK" "$WORK/test.log"; then
    err "Config TIDAK lolos uji di Xray $VER. Tidak ada yang diubah. Detail:"
    tail -n 15 "$WORK/test.log" | sed 's/^/    /'
    exit 1
fi
ok "Config lolos uji"
if grep -qiE "deprecat|will be removed|migrat" "$WORK/test.log"; then
    echo "${Y}[!] Peringatan deprecated pada uji config:${N}"; grep -iE "deprecat|will be removed|migrat" "$WORK/test.log" | sed 's/^/    /'
fi

# ---------------- 3. backup ----------------
BK="$BK_ROOT/$(date +%Y%m%d-%H%M%S)-sebelum-${VER}"
mkdir -p "$BK" || exit 1
cp -a "$CFG" "$BK/config.json"
[ "$FRESH" = 0 ] && cp -a "$BIN" "$BK/xray.bin"
cp -a "$UNIT" "$BK/" 2>/dev/null
[ -s "$BK/config.json" ] || { err "Backup gagal. Dibatalkan."; exit 1; }
[ "$FRESH" = 0 ] && { [ -s "$BK/xray.bin" ] || { err "Backup binary gagal. Dibatalkan."; exit 1; }; }
ok "Backup: $BK"

# ---------------- 4. pasang ----------------
info "Menghentikan daemon limit & xray ..."
systemctl stop $LIMITS >/dev/null 2>&1
systemctl stop xray >/dev/null 2>&1
if ! install -m 755 -o root -g root "$WORK/new/xray" "$BIN"; then
    err "Gagal memasang binary baru."
    [ "$FRESH" = 0 ] && restore_from "$BK"
    start_limits; exit 1
fi
# siapkan lingkungan jalan (aman dijalankan ulang)
mkdir -p /run/xray /var/log/xray
chown www-data:www-data /run/xray /var/log/xray
touch /var/log/xray/access.log /var/log/xray/error.log
chown www-data:www-data /var/log/xray/*.log
[ -f "$UNIT" ] || { info "Unit systemd xray belum ada, membuat ..."; write_unit; }
systemctl daemon-reload
systemctl enable xray >/dev/null 2>&1
systemctl restart xray
sleep 4

# ---------------- 5. cek kesehatan ----------------
FAIL=""
systemctl is-active --quiet xray || FAIL="$FAIL service-xray-tidak-aktif"
for p in 10001 10002 10003 10004 10005 10006 10007 10008; do
    ss -ltn 2>/dev/null | grep -q "127.0.0.1:$p " || FAIL="$FAIL port-$p-tidak-listen"
done
"$BIN" api statsquery --server="$API" >/dev/null 2>&1 || FAIL="$FAIL stats-api-gagal"
if journalctl -u xray --since "-30s" --no-pager 2>/dev/null | grep -qiE "failed to|panic|fatal"; then
    FAIL="$FAIL error-di-log-xray"
fi

if [ -n "$FAIL" ]; then
    err "Cek kesehatan gagal:${FAIL}"
    echo "--- journalctl -u xray (15 baris terakhir) ---"; journalctl -u xray -n 15 --no-pager 2>/dev/null
    if [ "$FRESH" = 0 ]; then
        err "Memulihkan versi lama ..."
        if restore_from "$BK"; then ok "Dipulihkan ke: $($BIN version | head -n1)"
        else err "PEMULIHAN GAGAL. Cek manual; backup ada di $BK"; fi
    else
        err "Pasang baru: tidak ada versi lama untuk dipulihkan. Perbaiki sesuai log di atas, lalu jalankan ulang."
    fi
    start_limits
    exit 1
fi

start_limits
ok "Xray sekarang: $($BIN version | head -n1)"
for u in xray $LIMITS; do echo "   $u: $(systemctl is-active $u)"; done
echo
info "Langkah manual yang masih disarankan:"
echo "   1. Tes koneksi dari klien: vmess/vless/trojan/ss, WS dan gRPC."
echo "   2. Buka menu cek kuota & limit IP, lalu coba tambah/hapus akun uji."
echo "   3. Rollback kapan saja:  ./update-xray.sh --rollback"
rm -rf "$WORK"
exit 0
