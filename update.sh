#!/bin/bash
# UPDATE SCRIPT - versi verbose: tiap langkah tampil + lama waktunya
REPO="https://raw.githubusercontent.com/Dekdoo12/autoscript/main"
PASS="HeyHeyMauDecryptYaAwokawok"
WGET="wget --timeout=20 --tries=3 -q --show-progress"
WORK="/tmp/upd"
SUM=()
T_ALL=$(date +%s)

step() {
    local title="$1" fn="$2" t0 rc dt
    t0=$(date +%s)
    echo -e "\n\033[1;33m[$(date +%H:%M:%S)] ▶ ${title}\033[0m"
    "$fn"; rc=$?
    dt=$(( $(date +%s) - t0 ))
    if [[ $rc -eq 0 ]]; then
        echo -e "\033[1;32m   ✔ OK (${dt}s)\033[0m"
        SUM+=("$(printf '%-44s %5ss  OK' "$title" "$dt")")
    else
        echo -e "\033[1;31m   ✘ GAGAL kode ${rc} (${dt}s)\033[0m"
        SUM+=("$(printf '%-44s %5ss  GAGAL' "$title" "$dt")")
    fi
    return $rc
}

cek_awal() {
    local n
    n=$(grep -cE '^(###|#&|#!) ' /etc/xray/config.json 2>/dev/null)
    echo "   Akun xray terdaftar : ${n:-0}"
    echo "   Load average        : $(cut -d' ' -f1-3 /proc/loadavg)  (CPU: $(nproc) core)"
    echo "   Disk / bebas        : $(df -h / | awk 'NR==2{print $4}')"
}

stop_limit() {
    systemctl stop limitvmess limitvless limittrojan limitshadowsocks >/dev/null 2>&1
    echo "   daemon kuota dihentikan sementara (counter xray tetap tersimpan, akan dinyalakan lagi di langkah akhir)"
}

unduh_menu() {
    rm -rf "$WORK" && mkdir -p "$WORK" && cd "$WORK" || return 1
    $WGET -O menu.zip "$REPO/Cdy/menu.zip" || return 1
    [[ -s menu.zip ]] || { echo "   menu.zip kosong"; return 1; }
    echo "   ukuran menu.zip: $(du -h menu.zip | cut -f1)"
}

ekstrak_menu() {
    cd "$WORK" || return 1
    7z x -y -bd -p"$PASS" menu.zip >/dev/null 2>&1 || { echo "   gagal ekstrak menu.zip (7z)"; return 1; }
    [[ -d menu ]] || { echo "   folder menu tidak ditemukan"; return 1; }
    echo "   $(ls menu | wc -l) file menu akan diperbarui:"
    ls -1 menu | paste -sd' ' | fold -s -w 76 | sed 's/^/     /'
}

pasang_menu() {
    cd "$WORK" || return 1
    chmod +x menu/*
    rm -rf /usr/local/sbin && mkdir -p /usr/local/sbin
    mv menu/* /usr/local/sbin/ || return 1
    echo "   terpasang di /usr/local/sbin"
}

cek_slowdns() {
    if [ -f "/etc/slowdns/install.sh" ] && [ -f "/etc/slowdns/slowdns.env" ]; then
        echo "   SlowDNS sudah terpasang, dilewati"
    else
        echo "   SlowDNS belum terpasang, memasang (bagian ini bisa lama)..."
        $WGET -O /tmp/nameserver "$REPO/Cfg/slowdns.sh" || return 1
        chmod +x /tmp/nameserver
        /tmp/nameserver
    fi
}

update_limit() {
    $WGET -O /tmp/limit.sh "$REPO/Fls/limit.sh" || return 1
    chmod +x /tmp/limit.sh
    /tmp/limit.sh
    local rc=$?
    rm -f /tmp/limit.sh
    return $rc
}

# [XRAY-TRANSPORTS] Aktifkan HTTPUpgrade & XHTTP di VPS yang sudah terpasang.
# Semua file dicadangkan dulu; jika Xray gagal hidup, semuanya dikembalikan otomatis.
update_transports() {
    local XV_NEED="26.11.9" XV_MIN="24.11.0"
    local XBIN="/usr/local/bin/xray" UNIT="/etc/systemd/system/xray.service"
    local NGX="/etc/nginx/conf.d/xray.conf" CONF="/etc/xray/config.json"
    local BAK cur dom new inst out

    [[ -f $CONF && -x $XBIN && -f $NGX && -f $UNIT ]] || { echo "   Xray/nginx belum terpasang lengkap, dilewati"; return 0; }
    dom=$(cat /etc/xray/domain 2>/dev/null)
    [[ -n $dom ]] || { echo "   /etc/xray/domain kosong, dilewati"; return 1; }
    BAK="/root/backup-transports-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BAK" && cp -a "$XBIN" "$UNIT" "$NGX" "$CONF" "$BAK"/ || { echo "   gagal membuat cadangan"; return 1; }
    echo "   cadangan: $BAK"

    _tr_rollback() {
        echo -e "   \033[1;31mMengembalikan konfigurasi lama dari $BAK ...\033[0m"
        cp -a "$BAK/xray.service" "$UNIT"; cp -a "$BAK/xray.conf" "$NGX"
        cp -a "$BAK/config.json" "$CONF"; install -m 755 "$BAK/xray" "$XBIN"
        systemctl daemon-reload
        nginx -t >/dev/null 2>&1 && systemctl reload nginx
        systemctl restart xray
    }

    # 1) skrip sinkronisasi (di /usr/local/bin karena /usr/local/sbin dikosongkan saat update menu)
    curl -fsSL --retry 3 --connect-timeout 20 -o /tmp/xray-sync.new "$REPO/Fls/xray-sync" \
        && [[ $(stat -c%s /tmp/xray-sync.new 2>/dev/null || echo 0) -ge 1000 ]] \
        || { echo "   unduh Fls/xray-sync gagal (belum ada di repo?)"; rm -f /tmp/xray-sync.new; return 1; }
    install -m 755 /tmp/xray-sync.new /usr/local/bin/xray-sync; rm -f /tmp/xray-sync.new

    # 2) nginx: lokasi HTTPUpgrade (1010) & XHTTP (1013)
    new=/tmp/xray.conf.new
    curl -fsSL --retry 3 --connect-timeout 20 -o "$new" "$REPO/Cfg/xray.conf" \
        && grep -q '/hu-vless' "$new" && grep -q '/xh-vless' "$new" \
        || { echo "   Cfg/xray.conf di repo belum berisi HTTPUpgrade/XHTTP, dibatalkan"; rm -f "$new"; return 1; }
    sed -i "s/xxx/${dom}/g" "$new"
    cp -f "$new" "$NGX"; rm -f "$new"
    if ! nginx -t >/dev/null 2>&1; then
        echo "   nginx -t GAGAL:"; nginx -t 2>&1 | tail -3 | sed 's/^/     /'
        _tr_rollback; return 1
    fi

    # 3) inti Xray: XHTTP butuh >= $XV_MIN
    cur=$("$XBIN" version 2>/dev/null | awk 'NR==1{print $2}')
    if [[ -n $cur ]] && printf '%s\n%s\n' "$XV_MIN" "$cur" | sort -V -C; then
        echo "   Xray $cur sudah mendukung XHTTP, versi tidak diubah"
    else
        echo "   Xray ${cur:-?} -> $XV_NEED (XHTTP butuh >= $XV_MIN)"
        inst=/tmp/xray-install-release.sh
        curl -fsSL --retry 3 --connect-timeout 20 -o "$inst" \
            https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh \
            && [[ -s $inst ]] && bash "$inst" install -u www-data --version "$XV_NEED" \
            || { echo "   pemasangan Xray $XV_NEED gagal"; rm -f "$inst"; _tr_rollback; return 1; }
        rm -f "$inst"
        cp -a "$BAK/xray.service" "$UNIT"   # installer resmi bisa menulis ulang unit; pakai unit Anda
    fi

    # 4) unit systemd: jalankan xray-sync sebelum Xray start (ExecStartPre; gagal tidak menghalangi start)
    if ! grep -q 'xray-sync' "$UNIT"; then
        sed -i '/^ExecStart=/i ExecStartPre=-+/usr/local/bin/xray-sync' "$UNIT" || { _tr_rollback; return 1; }
    fi
    systemctl daemon-reload

    # 5) bangun inbound baru dari akun yang ada, lalu uji sebagai user service
    /usr/local/bin/xray-sync
    if ! out=$(runuser -u www-data -- "$XBIN" run -test -config "$CONF" 2>&1); then
        echo "   uji config GAGAL:"; echo "$out" | tail -6 | sed 's/^/     /'
        _tr_rollback; return 1
    fi

    # 6) restart & pastikan hidup; jika tidak, kembalikan semuanya
    systemctl restart xray; sleep 4
    if ! systemctl is-active --quiet xray; then
        echo "   Xray tidak aktif setelah restart:"; journalctl -u xray -n 8 --no-pager 2>/dev/null | sed 's/^/     /'
        _tr_rollback; return 1
    fi
    nginx -t >/dev/null 2>&1 && systemctl reload nginx
    echo "   HTTPUpgrade & XHTTP aktif; akun lama ikut otomatis."
}

netfilter-persistent >/dev/null 2>&1
clear
echo -e "\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e " \e[1;97;101m          UPDATE SCRIPT        \e[0m"
echo -e "\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

step "Cek kondisi VPS" cek_awal
step "Hentikan daemon kuota sementara" stop_limit
if step "Unduh menu.zip" unduh_menu; then
    if step "Ekstrak menu.zip" ekstrak_menu; then
        step "Pasang menu ke /usr/local/sbin" pasang_menu
    fi
else
    echo -e "\033[1;31m   menu lama TIDAK diubah karena unduhan gagal\033[0m"
fi
step "Cek / pasang SlowDNS" cek_slowdns
step "Aktifkan HTTPUpgrade & XHTTP (Xray)" update_transports
step "Perbarui daemon kuota & service limit" update_limit

rm -rf "$WORK"
cd ~ 2>/dev/null
echo -e "\n\033[1;36m━━━━━━━━━━━━━━ RINGKASAN WAKTU ━━━━━━━━━━━━━━\033[0m"
for s in "${SUM[@]}"; do echo "  $s"; done
echo "  Total: $(( $(date +%s) - T_ALL ))s | Load sekarang: $(cut -d' ' -f1-3 /proc/loadavg)"
echo -e "\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo ""
read -n 1 -s -r -p "Press [ Enter ] to back on menu"
rm -f "$0"
menu
