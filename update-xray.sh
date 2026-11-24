#!/bin/bash
# update-xray.sh - update Xray core pada VPS script v5 yang sudah berjalan.
#
# Pemakaian:   ./update-xray.sh            (default 26.11.9)
#              ./update-xray.sh 26.11.9
#              ./update-xray.sh --rollback  (kembali ke backup terakhir)
#
# Alur: unduh -> verifikasi sha256 -> uji config dengan binary baru (belum ada
# yang diubah) -> backup -> ganti binary -> restart -> cek kesehatan.
# Kalau cek kesehatan gagal, binary dan config lama dipulihkan otomatis.
# Tidak menyentuh menu, unit systemd xray, /usr/local/sbin, atau data akun.

XRAY_VER_DEFAULT="26.11.9"
BIN="/usr/local/bin/xray"
CFG="/etc/xray/config.json"
ASSET="/usr/local/share/xray"
BK_ROOT="/root/xray-backup"
WORK="/tmp/xray-upd"
LIMITS="limitvmess limitvless limittrojan limitshadowsocks"
API="127.0.0.1:10000"

R=$'\033[1;31m'; G=$'\033[1;32m'; Y=$'\033[1;33m'; N=$'\033[0m'
info() { echo "${Y}[*]${N} $*"; }
ok()   { echo "${G}[OK]${N} $*"; }
err()  { echo "${R}[X]${N} $*" >&2; }

[ "$(id -u)" -eq 0 ] || { err "Jalankan sebagai root."; exit 1; }
for c in curl unzip sha256sum ss systemctl; do
    command -v "$c" >/dev/null 2>&1 || { err "Perintah '$c' tidak ditemukan."; exit 1; }
done
[ -x "$BIN" ] || { err "$BIN tidak ada. Xray belum terpasang lewat script v5?"; exit 1; }
[ -f "$CFG" ] || { err "$CFG tidak ada."; exit 1; }

start_limits() { systemctl start $LIMITS >/dev/null 2>&1; }

restore_from() {   # $1 = folder backup
    local d="$1"
    [ -f "$d/xray.bin" ] && [ -f "$d/config.json" ] || { err "Backup tidak lengkap di $d"; return 1; }
    systemctl stop xray >/dev/null 2>&1
    install -m 755 -o root -g root "$d/xray.bin" "$BIN" || return 1
    cp -a "$d/config.json" "$CFG" || return 1
    systemctl restart xray
    sleep 3
    systemctl is-active --quiet xray
}

# ---------------- mode rollback manual ----------------
if [ "$1" = "--rollback" ]; then
    LAST=$(ls -1dt "$BK_ROOT"/*/ 2>/dev/null | head -n1)
    [ -n "$LAST" ] || { err "Tidak ada backup di $BK_ROOT"; exit 1; }
    info "Rollback dari $LAST"
    systemctl stop $LIMITS >/dev/null 2>&1
    if restore_from "${LAST%/}"; then ok "Rollback selesai: $($BIN version | head -n1)"; start_limits; exit 0
    else err "Rollback gagal, cek manual: journalctl -u xray -n 50"; start_limits; exit 1; fi
fi

VER="${1:-$XRAY_VER_DEFAULT}"
VER="${VER#v}"
[[ "$VER" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { err "Format versi salah: $VER (contoh 26.11.9)"; exit 1; }

CUR=$($BIN version 2>/dev/null | head -n1)
info "Terpasang : ${CUR:-tidak diketahui}"
info "Target    : Xray $VER"
case "$CUR" in *" $VER "*) ok "Sudah versi $VER, tidak ada yang perlu dilakukan."; exit 0;; esac

# ---------------- 1. unduh + verifikasi ----------------
rm -rf "$WORK"; mkdir -p "$WORK/new" || exit 1
cd "$WORK" || exit 1
URL="https://github.com/XTLS/Xray-core/releases/download/v${VER}"
info "Mengunduh Xray-linux-64.zip ..."
curl -fL --retry 3 --connect-timeout 15 -o xray.zip "$URL/Xray-linux-64.zip" \
    || { err "Unduh zip gagal (versi ada? koneksi?)."; exit 1; }
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

# ---------------- 2. uji config dengan binary baru (belum mengubah apa pun) ----------------
info "Menguji $CFG dengan binary baru ..."
XRAY_LOCATION_ASSET="$ASSET" new/xray run -test -config "$CFG" > "$WORK/test.log" 2>&1
if ! grep -qi "Configuration OK" "$WORK/test.log"; then
    err "Config TIDAK lolos uji di Xray $VER. Tidak ada yang diubah. Detail:"
    tail -n 15 "$WORK/test.log" | sed 's/^/    /'
    exit 1
fi
ok "Config lolos uji"
if grep -qiE "deprecat|will be removed|migrat" "$WORK/test.log"; then
    echo "${Y}[!] Ada peringatan deprecated pada uji config:${N}"; grep -iE "deprecat|will be removed|migrat" "$WORK/test.log" | sed 's/^/    /'
fi

# ---------------- 3. backup ----------------
BK="$BK_ROOT/$(date +%Y%m%d-%H%M%S)-sebelum-${VER}"
mkdir -p "$BK" || exit 1
cp -a "$BIN" "$BK/xray.bin" && cp -a "$CFG" "$BK/config.json" \
    && cp -a /etc/systemd/system/xray.service "$BK/" 2>/dev/null
[ -s "$BK/xray.bin" ] && [ -s "$BK/config.json" ] || { err "Backup gagal. Dibatalkan."; exit 1; }
ok "Backup: $BK"

# ---------------- 4. ganti binary ----------------
info "Menghentikan daemon limit & xray ..."
systemctl stop $LIMITS >/dev/null 2>&1
systemctl stop xray >/dev/null 2>&1
if ! install -m 755 -o root -g root "$WORK/new/xray" "$BIN"; then
    err "Gagal memasang binary baru, memulihkan ..."
    restore_from "$BK"; start_limits; exit 1
fi
systemctl daemon-reload
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
    err "Memulihkan versi lama ..."
    if restore_from "$BK"; then ok "Dipulihkan ke: $($BIN version | head -n1)"
    else err "PEMULIHAN GAGAL. Cek manual: journalctl -u xray -n 50 ; backup ada di $BK"; fi
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
