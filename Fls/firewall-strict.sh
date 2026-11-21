#!/bin/bash
# OPSIONAL - tidak dipanggil installer. Mengubah firewall menjadi "default tolak" untuk INPUT,
# hanya mengizinkan port yang SAAT INI sedang listen di interface publik (+ SSH).
# Default = DRY-RUN (hanya menampilkan aturan). Terapkan:  ./firewall-strict.sh --apply
# Setelah --apply ada rollback otomatis 90 detik kecuali Anda mengetik YES (mencegah terkunci dari server).
set -u
APPLY=0; [ "${1:-}" = "--apply" ] && APPLY=1
ports() { # ports tcp|udp
  local flag="-ltnH"; [ "$1" = udp ] && flag="-lunH"
  ss $flag 2>/dev/null | awk '{print $4}' | grep -vE '^(127\.|\[::1\]|::1)' | sed -E 's/.*:([0-9]+)$/\1/' | grep -E '^[0-9]+$' | sort -un
}
TCP=$(ports tcp); UDP=$(ports udp)
SSHP=$(grep -hE '^Port ' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}'); TCP=$(printf '%s\n%s\n22\n' "$TCP" "$SSHP" | grep -E '^[0-9]+$' | sort -un)
RULES=()
RULES+=("-F INPUT" "-A INPUT -i lo -j ACCEPT" "-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT" "-A INPUT -p icmp -j ACCEPT")
for p in $TCP; do RULES+=("-A INPUT -p tcp --dport $p -j ACCEPT"); done
for p in $UDP; do RULES+=("-A INPUT -p udp --dport $p -j ACCEPT"); done
RULES+=("-P INPUT DROP")   # kebijakan DROP dipasang TERAKHIR agar sesi SSH berjalan tidak terputus
echo "Aturan yang akan diterapkan:"; printf '  iptables %s\n' "${RULES[@]}"
[ $APPLY = 1 ] || { echo; echo "(dry-run) tambahkan --apply untuk menerapkan."; exit 0; }
[ "$(id -u)" = 0 ] || { echo "Harus root."; exit 1; }
BAK=$(mktemp); iptables-save > "$BAK"
( sleep 90; iptables-restore < "$BAK"; echo "Rollback otomatis dijalankan." ) & RB=$!
for r in "${RULES[@]}"; do iptables $r || { kill $RB 2>/dev/null; iptables-restore < "$BAK"; echo "Gagal: iptables $r"; exit 1; }; done
read -t 85 -p "Koneksi masih normal? Ketik YES dalam 85 detik untuk mempertahankan: " ans
if [ "${ans:-}" = "YES" ]; then kill $RB 2>/dev/null; netfilter-persistent save >/dev/null 2>&1; echo "Firewall ketat dipertahankan & disimpan."; else echo "Tidak dikonfirmasi: rollback akan berjalan."; wait $RB; fi
